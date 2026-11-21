# Tools — 脚本与自研驱动骨架

本目录收录本次研究中实际执行过的全部脚本，以及从零写的探针 kext 骨架。
每个脚本都标注了**作用**、**运行环境**、**执行步骤**和**回滚方式**。

> 所有脚本均为只读或"先备份再修改"设计；不含任何联网、遥测或上传行为。

---

## 目录一览

| 文件 | 作用 | 运行环境 |
|---|---|---|
| `CMP40HX-Metal-Skeleton/` | 自研 IOKit 探针 kext 完整工程（源码 + 构建 + 取证） | macOS（编译）/ OpenCore（加载） |
| `mac-01-build.command` | 检查工具链 → 编译 kext → 产物校验 → 列出 EFI 分区 | macOS |
| `mac-02-install-kext.command` | 把编译产物复制到 ESP（自动探测卷，校验 SHA256） | macOS |
| `mac-99-do-everything.command` | **一键全流程**：编译 → 复制 → 备份 config → 加 Kernel>Add → 校验 → 双 ESP 同步 | macOS |
| `mac-99-revert.command` | 一键回滚：用最新备份恢复 config + 删除 kext + 校验 SHA | macOS |
| `efi-switch.sh` | OpenCore 配置方案切换器（status / switch / rollback / backup-efi / validate） | Windows Git Bash |

---

## 1. CMP40HX-Metal-Skeleton（自研探针 kext）

**作用**：不经过 NVIDIA 闭源 RM，直接以独立 IOKit 驱动认领 `10DE:1F0B`，
读取 `PMC_BOOT_0/1/42` 判断 GPU 是否响应寄存器读，结果写入 IORegistry 供取证。

**它不做什么**（重要）：不建立 IOAccelerator、不提供 Metal、不提交任何 GPU 命令。
详见 `CMP40HX-Metal-Skeleton/docs/HONEST-LIMITS.md`。

**执行步骤**：

```bash
cd CMP40HX-Metal-Skeleton
./build.sh                                  # 编译，内置 __kmod_info 断言
cp -R build/CMP40HXAccelerator.kext /Volumes/<USB_VOLUME>/EFI/OC/Kexts/
# 在 config.plist 的 Kernel > Add 增加一条（见 docs/MAC-OPERATIONS.md §4）
# 重启后：
bash tests/verify-skeleton.sh
```

**取证看三行**：

- `kmutil showloaded` 里是否有 `com.cmp40hx.skeleton.accelerator`
- 内核日志是否有 `CMP40HX-Probe: sample 0: boot0=0x...`
- `CMP40HX,verdict` = `GPU_ALIVE` / `GPU_NOT_RESPONDING`

---

## 2. mac-01-build.command

**作用**：一键编译 + 自检，避免手打命令出错。

```bash
bash mac-01-build.command
# 可选：编译后直接复制到指定 ESP
bash mac-01-build.command copy disk0s1
```

**产出**：桌面 `CMP40HX-BUILD-<时间戳>.txt`（工具链版本、编译警告、`__kmod_info` 断言、SHA256）。

---

## 3. mac-02-install-kext.command

**作用**：只复制 kext，不改 config。自动扫描 `/Volumes` 找含 `EFI/OC/Kexts` 的卷，
并在目标端重新计算 SHA256 与源比对（检测 U 盘写入异常）。

```bash
bash mac-02-install-kext.command
```

---

## 4. mac-99-do-everything.command（推荐）

**作用**：把上面几步合成一次执行，共 7 步：

| 步 | 动作 | 保护措施 |
|---|---|---|
| 1 | 定位 U 盘 | 扫描 `/Volumes`，不写死卷标 |
| 2 | 工具链检查 | 缺 Xcode CLT 直接中止 |
| 3 | 编译 | 强制重编译；`otool` 断言 `__kmod_info`，缺失即 `exit 4` |
| 4 | 复制 kext | 双向 SHA256 比对 |
| 5 | 备份 config | `config.plist.bak-<时间戳>`，备份失败则中止 |
| 6 | 写入 `Kernel>Add` | `plutil -lint` 校验；失败自动恢复备份 |
| 6.5 | 同步内置 ESP | 解析 APFS 物理存储定位 ESP，sudo 挂载后同步，双份 SHA 核对 |
| 7 | 差异核对 | boot-args / DeviceProperties / ACPI / PlatformInfo / Misc 逐项比对 |

```bash
bash mac-99-do-everything.command
```

**幂等**：条目已存在时输出 `ALREADY`，不会重复添加。

---

## 5. mac-99-revert.command

**作用**：回滚到最近一次备份。

```bash
bash mac-99-revert.command
```

它会打印恢复后的 config SHA256，便于与原始基线比对。

---

## 6. efi-switch.sh（Windows 侧）

**作用**：在多个 OpenCore 配置方案之间切换，并保证"校验 → 快照 → 部署 → 复核"四步安全链。

```bash
./efi-switch.sh status          # 按 SHA256 识别当前部署的是哪个方案
./efi-switch.sh switch plan-a   # 切换（自动备份当前 config）
./efi-switch.sh rollback        # 回滚到已验证基线
./efi-switch.sh backup-efi      # 整包备份 EFI
./efi-switch.sh validate        # 用 ocvalidate 校验目标方案
```

> 注意：脚本内部路径使用 POSIX 风格（`/f/...`），Windows 下需用 Git Bash 运行。

---

## 安全与边界

- 所有脚本**不修改** SMBIOS / ACPI / USB / 音频等无关配置
- 修改 config 前必先备份，且备份失败即中止
- 探针 kext 在 `probe` 阶段只读寄存器，显式关闭 Bus Master（不发起 DMA）
- `IOProbeScore = 40000` 会压过 NullMoth 的 NVRM(1000)，**测 NullMoth 前必须先移除探针**
