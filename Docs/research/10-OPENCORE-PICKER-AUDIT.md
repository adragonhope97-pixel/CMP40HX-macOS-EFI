# 10-OPENCORE-PICKER-AUDIT(v1.0,2026-11-01)

> 性质:只读审计。config 实读 + bcdedit 固件项枚举(L3)+ OpenCore 1.0.8 源码依据(B)。**未修改任何文件/变量。**
> 审计对象:`<系统 EFI 分区>/EFI\OC\config.plist`(SHA-256 `7f73fe6b…`,Exp-N1 部署版)+ 固件 NVRAM 只读探测。

## 1. Misc → Boot / Security 实测值

| 键 | 值 | 评注 |
|----|-----|------|
| ShowPicker | **true** | 每次显示 Picker ✅ |
| **Timeout** | **5** | 倒计时 5 秒(用户反馈"很短"即此) |
| **TakeoffDelay** | **0** | 无启动前延迟(仅键盘初始化慢时才需要调整) |
| PickerMode | Builtin | 内建 Picker |
| **PickerAttributes** | **17** (0x11) | OC_ATTR_USE_VOLUME_ICON(0x1)+ OC_ATTR_USE_FLAVOUR_ICON(0x10) |
| HideAuxiliary | false | 辅助项也显示(列表更长) |
| LauncherOption | Disabled | OC 不注册固件启动项 ✅(与 bcdedit 结果一致) |
| **AllowSetDefault** | **true** | **Ctrl+Enter / Ctrl+数字 保存默认项已可用** ✅ |
| PollAppleHotKeys(Misc→Boot) | false | Apple 热键轮询关闭 |

## 2. UEFI 层

| 键 | 值 | 评注 |
|----|-----|------|
| **RequestBootVarRouting** | **true** | OC 默认项变量写入 **OC 专属变量空间**,不污染固件 BootOrder ✅ |
| KeySupport | **true** | 内建键盘驱动(Picker 阶段键盘可用) |
| KeySupportMode / KeyForgetThreshold / KeySwap | Auto / 5 / false | 默认 ✅ |
| PointerSupport | false | — |
| 启用的 Drivers | apfs_aligned / HfsPlus / OpenRuntime / ResetNvramEntry | **无 OpenUsbKbDxe、无重复键盘驱动** ✅ |

## 3. 固件启动项(bcdedit /enum firmware,L3 实测)

```
{fwbootmgr} displayorder = {bootmgr} → {e7424571…} → {5291e2e8…},timeout = 1 秒
```

- **固件第 1 优先 = Windows Boot Manager,固件超时仅 1 秒**。
- **发现 3 条 "Windows Boot Manager" 固件项**(其中两条 device=unknown,疑似陈旧残留)→ 固件层存在重复启动项(与 OC Picker 无关,OC 因 LauncherOption=Disabled 不注册固件项)。
- OpenCore 由 `<系统 EFI 分区>/EFI\BOOT\BOOTX64.EFI` 路径或固件菜单人工选择进入。
- 清理固件重复项属固件操作,**本阶段不执行**(与 OC Picker 行为无因果)。

## 4. NVRAM 默认项变量

| 项 | 结果 |
|----|------|
| OC vendor 空间(Boot0080/BootOrder) | **UNKNOWN** —— Windows 非提升权限读取被拒(win32 1314,需 SeSystemEnvironmentPrivilege) |
| 判定 | 无法确认"是否存在已保存默认项";但结合"默认总是第 1 项"的用户现象,推断 **从未保存过默认项** [E 级推断,已标注] |

## 5. 默认项机制(OpenCore 1.0.8 源码,B 级)

| 位置 | 语义 |
|------|------|
| `BuiltinPicker.c` L242/L377-378 | 倒计时高亮并自动启动 **`DefaultEntry`**;超时即启动它 |
| `DefaultEntryChoice.c` `OcSetDefaultBootEntry`(L772-) | `AllowSetDefault=false` → 拒绝(SECURITY_VIOLATION);**本机 = true,可用** |
| 同文件 L848+ | 保存机制 = 写 **Boot0080** + 重排 BootOrder;因 `RequestBootVarRouting=true`,写入 **OC 专属变量空间**(固件 BootOrder 不受影响) |
| `HotKeySupport.c` L318/L332 | **"Default update is desired for Ctrl+Index and Ctrl+Enter"**(AllowSetDefault 时) |

**默认为什么总是第 1 项(源码级答案)**:`DefaultEntry` 的取值 = NVRAM 中已保存的默认(Boot0080);**没有保存记录时回退为第一项**。当前 NVRAM 推断无保存记录(用户未使用过 Ctrl+Enter)→ 每次开机高亮第 1 项,5 秒后自动启动它。

## 6. 问题与建议(全部零修改方案优先)

| 编号 | 建议 | 优先级 | 修改 | 风险 | 回滚 | 需重启 |
|------|------|--------|------|------|------|--------|
| PICK-1 | **在 Picker 中选中 macOS 后按 Ctrl+Enter**(保存默认;Ctrl+数字 亦可直接保存对应项) | **P3(体验)** | **无**——写入 OC 专属变量,不碰固件 BootOrder | 极低(Reset NVRAM 或重新 Ctrl+Enter 即改) | Reset NVRAM | **下次开机观察高亮** |
| PICK-2 | Timeout 5 → 10(如需更长决策时间) | P3 | config 单键 | 极低 | 备份还原 | 是 |
| PICK-3 | TakeoffDelay | **保持 0** | — | — | — | — |
| PICK-4 | AllowSetDefault | **保持 true**(已满足需求) | — | — | — | — |
| PICK-5 | 固件层 3 条重复 Windows Boot Manager 清理 | P3(与 OC 无关) | 固件操作 | 低 | bcdedit 可重建 | 否 |
| PICK-6 | 键盘驱动 | **保持现状**(无重复驱动;KeySupport=true 正常) | — | — | — | — |

## 7. 方向键响应延迟问题

- 无证据表明存在延迟:KeySupport=true 内建方案 + KeyForgetThreshold=5 + TimerResolution=50000 均为常规值,无重复键盘驱动。
- 若实机仍感觉方向键响应差:可尝试 `KeySupportMode=Auto → V2/AMI`(需逐项验证),或添加 OpenUsbKbDxe(仅 USB 键盘场景)——**当前无证据支持,不做建议**。[E 级]

## 8. 结论

1. **默认总是第 1 项** = 从未保存过默认项(OC 回退规则),不是配置错误。
2. **指定 macOS 为默认** = 零修改方案:Picker 中选 macOS → **Ctrl+Enter**(AllowSetDefault 已为 true)。
3. **Timeout**:建议先用 Ctrl+Enter;如仍嫌 5 秒短,再批准确 10 秒(config 单键)。
4. **TakeoffDelay**:无需调整(0 为正常)。
5. **AllowSetDefault**:无需调整(已为 true)。
6. 每项修改(仅 PICK-2 涉及 config)风险极低、回滚为单文件备份还原;PICK-1 完全无文件修改。

**本阶段未修改任何文件或变量。**
