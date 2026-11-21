# 7 个导致 kext"静默不加载"的缺陷

这份文档记录从零写 kext 时踩到的全部坑。每一条都曾让 kext **加载不了或 attach 不上，
而且系统不会给出任何明显错误**——这正是最耗时间的地方。

## 1. 缺 `__kmod_info` 段（最致命）

**现象**：kext 放进 ESP、config 也加了条目、OpenCore 不报错、系统正常启动，
但 `ioreg -c <类名>` 为空，内核日志一条没有。

**原因**：手工 `clang -r -Wl,-kext` 链接不会自动生成 `__DATA,__kmod_info` 段，
内核不认为这是可加载 kext，OpenCore 静默跳过。

**验证方法**：

```bash
otool -l build/X.kext/Contents/MacOS/X | grep -A2 kmod_info
```

**修复**：源码显式声明（`used` 防优化）：

```cpp
extern "C" {
    __attribute__((used, section("__DATA,__kmod_info")))
    static kmod_info_t gKmodInfo = {
        0, 1, 0, "com.example.kext", "0.2.0",
        0, 0, 0, 0, 0, 0, 0,
    };
}
```

> 注意：Apple 的 `KMOD_EXPLICIT_DECL` 宏在 clang 21 + gnu++17 下**没有生成该段**，
> 必须显式声明。兜底方案是用 `-Wl,-sectcreate,__DATA,__kmod_info,<200字节 blob>`。

## 2. `IONameMatch` 永远匹配不上

**现象**：`kmutil` 能看到 kext，但 `ioreg` 没有实例。

**原因**：IOPCIFamily 给**所有显示类设备**（class `0x03xxxx`，含 `0302` 3D controller）
的 `name` 属性都是 `display`，不是 `pci10de,xxxx`。IOKit 匹配表是**与关系**，
写 `IONameMatch pci10de,1f0b` 永不成立。

**修复**：用 `IOPCIPrimaryMatch`（厂商/设备）+ `IOPCIClassMatch`（设备类）。

## 3. 缺 `com.apple.iokit.IOPCIFamily` 依赖

**现象**：加载失败，或加载后符号解析错误。

**原因**：二进制引用了 `IOPCIDevice::metaClass`、`extendedConfigRead*` 等符号，
但 `OSBundleLibraries` 只写了 `com.apple.kpi.*`。

**修复**：

```xml
<key>com.apple.iokit.IOPCIFamily</key><string>1.0.0b1</string>
```

**自查**：解析 Mach-O 的未定义符号，确认每个都有提供者。

## 4. DeviceProperties 的 `device-id` spoof 破坏匹配

**现象**：明明写了 `IOPCIPrimaryMatch = 0x1f0b10de`，却匹配不上。

**原因**：若该节点被注入了 `device-id`（例如为了 spoof 成别的卡），
而 IOPCIFamily 的匹配读的是注入后的属性，就会看到 spoof 后的值。

**修复**：改用**厂商 + 设备类**匹配（`0x000010de&0xffff` + `0x03000000&0xff000000`），
真正的设备身份校验放到 `start()` 里读 config space 完成。

## 5. class 码精确匹配过窄

**现象**：同一张卡，有时匹配、有时不匹配。

**原因**：`IOPCIClassMatch = 0x03020000&0xffffff00` 只认 `0302`；
若实际读成 `0300`（VGA）就失配。

**修复**：放宽为 `0x03000000&0xff000000`（任意 0x03），身份校验交给代码。

## 6. Info.plist 里有 XML 注释

**现象**：kext 完全不加载，且没有任何提示。

**原因**：OpenCore 使用自带 XML 解析器，对注释的支持不确定；解析失败会直接跳过该 kext。

**修复**：发布用的 Info.plist 剥离全部注释，只留纯数据。

## 7. 缺 `__TEXT,__info_plist` 段

**现象**：多数情况下不影响（OC 从磁盘读 `PlistPath`），但结构不标准。

**修复**：链接时加

```bash
-Wl,-sectcreate,__TEXT,__info_plist,src/Info.plist
```

## 附：还有两个"不算缺陷但会咬人"的点

| 项 | 说明 |
|---|---|
| 越界读 | 读 `BAR0+0xA00` 前必须确认映射长度 ≥ `0xA04`，否则可能触发内核缺页 |
| 失效签名 | 改过 Info.plist 后 `_CodeSignature` 就失效了；要么重新签名，要么删掉（明确为未签名） |

## 排查顺序（省时间）

```
kmutil 里有没有？ ──否──→ 加载期问题：__kmod_info / 依赖 / 注释 / 签名
        │是
        ↓
ioreg 里有没有？ ──否──→ 匹配问题：IONameMatch / device-id spoof / class 码
        │是
        ↓
日志里有探针输出吗？ ──否──→ start() 提前返回：身份校验 / BAR 映射失败
        │是
        ↓
看 verdict 与采样值
```
