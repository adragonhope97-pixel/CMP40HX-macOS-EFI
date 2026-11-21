# macOS 端操作手册（通用版）

目标：编译自研探针 kext → 放入 ESP → 启用 → 取证。
以下路径均为通用写法，按自己的环境替换。

---

## 0. 准备

- macOS 15/26（x86_64）
- Xcode Command Line Tools：`xcode-select --install`
- 一块能读写的 U 盘（FAT32/exFAT），或直接操作内置 ESP
- 已能正常引导的 OpenCore（本工程只增加一个 kext 条目，不改动其它配置）

---

## 1. 把工程放到桌面

```bash
cp -R /Volumes/<USB_VOLUME>/CMP40HX-Metal-Skeleton ~/Desktop/
cd ~/Desktop/CMP40HX-Metal-Skeleton
```

---

## 2. 编译

```bash
chmod +x build.sh
./build.sh
```

**成功标志**（缺一不可）：

```
-- sections (必须有 __kmod_info) --
  sectname __kmod_info   segname __DATA
OK: __kmod_info 段存在
```

构建脚本内置断言：没有 `__kmod_info` 段会直接 `exit 4`，不会产出"看起来成功但内核不加载"的 kext。

---

## 3. 放入 ESP

U 盘若本身就是 FAT32 分区（非 ESP），macOS 会直接挂载，**不需要 mount**：

```bash
cp -R build/CMP40HXAccelerator.kext /Volumes/<USB_VOLUME>/EFI/OC/Kexts/
ls /Volumes/<USB_VOLUME>/EFI/OC/Kexts/
```

若是内置 ESP：

```bash
diskutil list                                  # 找到 EFI 分区，如 disk0s1
sudo diskutil mount disk0s1
cp -R build/CMP40HXAccelerator.kext /Volumes/EFI/OC/Kexts/
```

---

## 4. 启用条目

在 `config.plist` 的 `Kernel > Add` 增加一条：

| 键 | 值 |
|---|---|
| BundlePath | `CMP40HXAccelerator.kext` |
| ExecutablePath | `Contents/MacOS/CMP40HXAccelerator` |
| PlistPath | `Contents/Info.plist` |
| Arch | `Any` |
| Enabled | `true` |
| MinKernel / MaxKernel | 留空 |

**改前先备份 config.plist**，改后用 `plutil -lint` 或 `ocvalidate` 校验。
仓库 `Tools/mac-99-do-everything.command` 会自动完成这一步（含备份、校验、差异核对）。

---

## 5. 重启取证

```bash
bash tests/verify-skeleton.sh
```

看三个证据：

1. `[0] kmutil showloaded` 是否出现 `com.cmp40hx.skeleton.accelerator`
2. `[4] 内核日志` 是否出现 `CMP40HX-Probe: sample 0: boot0=0x...`
3. `[2] 属性` 中 `CMP40HX,verdict` 是 `GPU_ALIVE` 还是 `GPU_NOT_RESPONDING`

---

## 6. 回滚

```bash
bash Tools/mac-99-revert.command     # 自动用最新备份恢复 config + 删除 kext
```

或手工：

```bash
rm -rf /Volumes/<USB_VOLUME>/EFI/OC/Kexts/CMP40HXAccelerator.kext
# 并把 config.plist 里那条 Kernel>Add 删除
```

---

## 7. 常见坑

| 现象 | 原因 | 处理 |
|---|---|---|
| `ioreg` 为空、日志无输出 | kext 缺 `__kmod_info` 段 | 用本仓库的 build.sh（含断言） |
| `kmutil` 有、`ioreg` 空 | 匹配条件不成立 | 用 `IOPCIPrimaryMatch`（厂商/设备），不要用 `IONameMatch pci10de,xxxx` |
| 加载失败、符号解析错误 | 缺 `com.apple.iokit.IOPCIFamily` 依赖 | 在 `OSBundleLibraries` 补上 |
| 改了配置却毫无变化 | 引导的是另一块 ESP | 确认实际引导介质；或两份 ESP 同步部署 |
| OpenCore 不报错但 kext 不加载 | Info.plist 里有 XML 注释导致解析失败 | 剥离注释 |
