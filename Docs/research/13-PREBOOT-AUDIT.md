# 13. 探针加载前的风险审计（两轮合并）

> 本文合并原 20/21 号报告，记录启动前静态审计发现的全部缺陷与修复。

日期：2026-11-21 09:55
方法：对已部署的 kext 二进制做 Mach-O 结构解析 + 对 Info.plist/配置逐项核对 + 与 NullMoth 的匹配规则对照

## A. 已修复（本轮发现，均为"必然失败"级）

### A1. IONameMatch 永远匹配不上（致命）

原 personality：

```xml
<key>IONameMatch</key><string>pci10de,1f0b</string>
```

**错。** IOPCIFamily 给所有显示类设备（class `0x03xxxx`,含 CMP 的 `0302` 3D controller）的
`name` 属性都是 **`display`**——这一点由 NullMoth 自己的源码注释确认：

> `IONameMatch display alone, which IOPCIFamily gives EVERY display-class PCI device`

IOKit 的匹配表是**与关系**，`IONameMatch = pci10de,1f0b` 永不成立 → kext 会加载但**永不 attach**,
表现就是"`kmutil` 有、`ioreg` 空"。

**改为**：

```xml
<key>IOPCIPrimaryMatch</key><string>0x1f0b10de</string>
```

### A2. 缺 com.apple.iokit.IOPCIFamily 依赖（致命）

解析 Mach-O 符号表：**294 个未定义符号**,其中包含

```
__ZN11IOPCIDevice9metaClassE            (IOPCIDevice::metaClass)
__ZN11IOPCIDevice20extendedConfigRead16Ey
__ZN11IOPCIDevice20extendedConfigRead32Ey
```

但 `OSBundleLibraries` 只声明了 `com.apple.kpi.{bsd,iokit,libkern,mach}`。
加载期符号解析缺少提供者 → 加载失败。

**补上**：

```xml
<key>com.apple.iokit.IOPCIFamily</key><string>1.0.0b1</string>
```

### A3. 失效签名

修改 Info.plist 后 `Contents/_CodeSignature` 的封印已不匹配。OpenCore 注入不校验签名，
但"无效签名"比"未签名"更容易触发额外检查 → 已删除该目录（两份 ESP 同步）。

### A4. 取证脚本日志窗口

`log show --last 15m` → `30m`,避免操作较慢时漏掉内核消息。

## B. 已知并接受的风险

| # | 风险 | 评估 |
|---|---|---|
| B1 | `__kmod_info` 段为 **196 字节**（SDK 的 `kmod_info_t` 为 packed 布局，非 200） | 与 SDK 一致；若内核不认，表现为加载失败，可由 OC 日志确认 |
| B2 | 无 `__TEXT,__info_plist` 段 | OC 从磁盘按 `PlistPath` 读 plist，理论上不需要；若注入失败，首选补救是加 `-sectcreate __TEXT __info_plist` |
| B3 | GPU 无响应时最多 **12 秒**轮询延迟 | 设计如此（Turing 上电需约 10s 稳定）；可接受 |
| B4 | ProbeScore 40000 压过 NVRM(1000) | 实验期有意；**测 NullMoth 前必须移除探针**,否则 RM 永不绑定 |
| B5 | D3cold/链路断开时读 BAR0 理论上有总线错误风险 | 低；PCIe 对无响应设备通常返回全 F 而非 fault |

## C. 一个好消息

`NVRMFBClaim` 的 `IOMatchCategory = IOFramebuffer`,我们的 kext 用默认类别（IOService）。
**IOKit 允许不同 match category 的驱动同时 attach 同一设备** → 二者不冲突，探针不需要"抢赢"它。
真正的竞争者是 NVRM（同为 IOService 类别，ProbeScore 1000 < 40000），我们会赢，
因此 NVRM 不会去碰 BAR0，不存在两个驱动同时操作寄存器的风险。

## D. 当前双 ESP 状态（逐字节一致）

| 项 | G:（U 盘） | Z:（内置 ESP） |
|---|---|---|
| config.plist | `3a61c901…`(13 条) | `3a61c901…`(13 条) |
| kext 二进制 | `e4cfbf39…`(含 `__kmod_info`) | `e4cfbf39…` |
| kext Info.plist | `IOPCIPrimaryMatch=0x1f0b10de` | 同 |
| `_CodeSignature` | 已移除 | 已移除 |

## E. 仍待验证

1. 内核是否接受 196 字节的 `kmod_info`
2. 实际引导的是哪份 ESP（两份已一致，但 OC 日志会落在实际引导的那份根目录，可反查）
3. 探针 attach 后 BAR0 读是否真的返回真实值


---

# 第二轮审计（原 21 号报告）

## 1. 本轮新修

| # | 问题 | 处理 |
|---|---|---|
| 1 | `IOPCIClassMatch` 用 `0302` 精确匹配，若 class-code 读成 `0300` 则失配 | 放宽为 `0x03000000&0xff000000`（任意 0x03 显示类），身份校验由 `probe()` 读 config space 完成 |
| 2 | Info.plist 里有 XML 注释，OpenCore 自带解析器对注释支持不确定 | 剥离全部注释，只留纯数据 |
| 3 | `pollPMC()` 读 `BAR0+0xA00` 前只校验映射长度 ≥ 4 | 增加边界检查（需 ≥ 0xA04），不足时退化为只读 BOOT_0/1 |
| 4 | 源码曾发布空 `MetalPluginName` | 确认二进制中不存在该字符串 |

## 2. 本轮验证通过（无问题）

| 检查 | 结果 |
|---|---|
| 294 个未定义符号 | 全部由 kernel/libkern/IOKit/IOPCIFamily 提供；无 libc++/libSystem 依赖 |
| LC_UUID / LC_DYSYMTAB / LC_SOURCE_VERSION | 均存在 |
| Mach-O 类型 / 架构 | `MH_KEXT_BUNDLE` / `x86_64` |
| `__kmod_info` | 196 字节 = XNU `#pragma pack(4)` 的正确大小；name 与 bundle id 一致 |
| ESP 垃圾文件 | 无 `._*` AppleDouble、无零字节文件 |
| 双 ESP 三件套 | config / Info.plist / 二进制 SHA 完全一致 |
| `Kernel>Patch` | 空（没有补丁干扰符号解析） |
| `ACPI>Patch` | 空（没有设备重命名） |
| boot-args | 无 `nv_disable=1`、无 `-wegnoegpu` |
| `Kernel>Add` | 13 条，无重复，`Block` 仅 `IONDRVSupport` |
| SecureBootModel / Vault | Disabled / Optional |
| ocvalidate | 两份 config 均零错误 |

## 3. 匹配竞争矩阵（完整）

| 驱动 | 匹配类别 | 分数 | 与本探针冲突？ |
|---|---|---|---|
| CMP40HXAccelerator（本工程） | 默认(IOService) | 40000 | — |
| NVRM | 默认(IOService) | 1000 | 否（低分） |
| NVAccel | IOAccelerator | 100 | 否（不同类别） |
| NVRMFBClaim | IOFramebuffer | 30000 | 否（不同类别） |
| WEG NVHDAEnabler | IOFramebuffer | 300000 | 否（不同类别） |

IOKit 每个 match category 只允许一个驱动 → 只有 NVRM 同类，且 40000 > 1000。
**结论：探针会赢，NVRM 不会绑定，因此不存在两个驱动同时操作 BAR0 的风险。**

## 4. 剩余三项（静态无法解决）

1. 内核是否接受 OC 注入的这个 kext（只能重启验证）
2. 实际引导的是哪份 ESP（两份已逐字节一致，因此不影响结果）
3. BAR0 读是否返回真实值（这就是实验本身）
