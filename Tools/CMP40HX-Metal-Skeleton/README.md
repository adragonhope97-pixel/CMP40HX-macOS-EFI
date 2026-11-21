# CMP40HX 探针 kext v0.2（PMC 寄存器探针）

NVIDIA CMP 40HX（`10DE:1F0B`，TU106）的**独立 IOKit 驱动**，不依赖 NVIDIA 闭源 RM。
它不追求加速，只做一件最关键的事：**判定这张卡在 macOS 下到底响不响应寄存器读**。

## 为什么需要它

历史结论曾把驱动失败归因为"RM 内部支持表不含 CMP SKU"。源码核对后发现该结论错误：

- `0xF` 不是 `NV_ERR_NOT_SUPPORTED`（0x56），而是 **`NV_ERR_GPU_IS_LOST`**（GPU 掉线）
- `rm_is_supported_device()` **不查 PCI ID 表**，只读 `PMC_BOOT_0/42`，两者全 `0xFFFFFFFF` 就返回 0xF
- HAL 按 `PMC_BOOT_42` 的架构匹配（TU106 = arch `0x16` / impl `6`）

所以真正的问题可能是"卡没响应"，而不是"卡不被支持"。本探针用来验证这一点。

## 它做什么

| 动作 | 说明 |
|---|---|
| 认领设备 | `IOPCIPrimaryMatch` 厂商 10DE + `IOPCIClassMatch` 0x03，ProbeScore 40000 |
| 读身份 | 从 **PCI config space** 读 vendor/device（不受 DeviceProperties spoof 影响） |
| 记录 PCI 状态 | command 寄存器、BAR0/1/2、PMCSR；必要时把设备拉回 D0 |
| 轮询 PMC | `PMC_BOOT_0(0x0)` / `PMC_BOOT_1(0x4)` / `PMC_BOOT_42(0xA00)`，24 次 × 500ms |
| 判定 | 写入 `CMP40HX,verdict = GPU_ALIVE` 或 `GPU_NOT_RESPONDING` |
| 解码 | 若 ALIVE，解出 arch/impl 并判断是否 TU106 |

## 它不做什么

- 不建立 IOAccelerator / IOAccelerator2
- 不提供 Metal 插件，不提交任何 GPU 命令
- 不碰 GSP 固件、不碰 NVIDIA RM
- 不发起 DMA（显式 `setBusMasterEnable(false)`）

**任何"探针加载成功 = 加速成功"的说法都是错的。**

## 目录

```
src/CMP40HXAccelerator.hpp        类声明
src/CMP40HXAccelerator.cpp        实现（枚举 / BAR0 映射 / PMC 轮询 / 属性发布）
src/Info.plist                    IOKit 匹配与依赖声明
src/kmod_info.bin                 200 字节 kmod_info 兜底二进制（-sectcreate 用）
build.sh                          构建脚本（含 __kmod_info 断言）
tests/verify-skeleton.sh          Mac 端取证（只读）
docs/HONEST-LIMITS.md             技术边界、风险、与 NullMoth 共存问题
docs/DEFECTS-AND-FIXES.md         7 个导致"静默不加载"的缺陷与修复
docs/MAC-OPERATIONS.md            逐步操作手册（通用路径版）
```

## 构建

```bash
./build.sh
```

必须看到：

```
OK: __kmod_info 段存在
```

构建脚本内置 `otool` 断言，缺段直接 `exit 4`。

## 加载

优先 OpenCore 注入（不校验签名）：把 `build/CMP40HXAccelerator.kext` 放进 `EFI/OC/Kexts/`，
并在 `Kernel > Add` 增加条目（`BundlePath` / `ExecutablePath` / `PlistPath` / `Arch=Any` / `Enabled=true`）。

## 取证

```bash
bash tests/verify-skeleton.sh
```

三行关键证据：

```
[0] kmutil showloaded | grep cmp40hx     → 是否被内核加载
[4] 内核日志 CMP40HX-Probe: sample 0 ... → 探针是否真的运行
[2] CMP40HX,verdict                      → GPU_ALIVE / GPU_NOT_RESPONDING
```

## 结果解读

| verdict | 含义 | 下一步 |
|---|---|---|
| `GPU_ALIVE` + `is-tu106 = Yes` | 卡在 macOS 下是活的，驱动失败另有原因（时序/BAR） | 回到 RM 侧排查时序，Metal 有戏 |
| `GPU_ALIVE` + `is-tu106 = No` | 硅片信息异常 | 按实际 arch/impl 查 HAL 对应 |
| `GPU_NOT_RESPONDING` | 卡确实不响应 | 查 BAR 分配 / 电源 / ASPM |
| 加载即 panic | BAR 读触发总线错误 | 加长等待、限制读宽度 |

## 许可

与主仓库一致：MIT；转载或改进后发布请注明来源（本仓库链接 + "基于 CMP 40HX EFI 项目"）。
