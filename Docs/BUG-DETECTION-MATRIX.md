# 08 Bug 检测矩阵(v1.0)

状态:CONFIRMED(有证据)/ SUSPECTED(推断,待 L4)/ NOT TESTED。检测工具见 09;L4 才能闭环。

## A. EFI 配置
| ID | Bug | 严重度 | 发生条件 | 复现/检测 | 状态 |
|----|-----|--------|----------|-----------|------|
| BUG-EFI-004 | Lilu 不在 kext 链首 | 低 | 始终 | efi-audit.sh E04 | CONFIRMED(功能无碍) |
| BUG-EFI-007 | HfsPlus.efi/apfs_aligned.efi 来源不可追溯 | 中 | 供应链 | 哈希对账(无官方源可比) | CONFIRMED |
| BUG-EFI-008 | OC 二进制为定制构建,版本不可证 | 中 | 始终 | 与官方 1.0.4–1.0.8 哈希比对 | CONFIRMED |
| BUG-EFI-009 | 音频 layout-id 缺失 | 高 | 音频使用 | efi-audit + L4 音频测试 | CONFIRMED(缺失事实) |
| BUG-EFI-010 | USB 通用映射非板级定制 | 中 | USB 端口/睡眠 | L4 端口遍历 | CONFIRMED(事实)/影响 NOT TESTED |
| BUG-EFI-011 | plist 键序/废弃键 | — | — | ocvalidate 1.0.8 = 0 issues | PASS(无) |

## B. ACPI
| ID | Bug | 状态 |
|----|-----|------|
| BUG-ACPI-* | 编译/命名/EC/RTC 冲突 | NOT TESTED(需 L4 DSDT 反编译 + iasl;当前 6 SSDT 与两案例交叉一致,低风险) |

## C. P630
| ID | Bug | 严重度 | 证据 | 状态 |
|----|-----|--------|------|------|
| BUG-P630-001 | 图形加速未生效(-igfxvesa 强制 VESA)→ 20FPS/14MB | 高 | boot-args + 用户实测 20FPS + 14MB | CONFIRMED(现象)/根因待 L4 闭环 |
| BUG-P630-002 | 睡眠唤醒后显示恢复 | — | L4 | NOT TESTED |
| BUG-P630-003 | Metal 状态(预计 Unsupported,属 VESA 结果) | — | L4 SPDisplays | NOT TESTED |

## D. CMP 40HX
| ID | Bug | 严重度 | 状态 |
|----|-----|--------|------|
| BUG-CMP-000 | 驱动层 0/4(未安装) | — | 设计现状(非缺陷) |
| BUG-CMP-001 | 1F0B 不在 615.78.08 提取表 | 信息 | CONFIRMED(回退放行,NVIDIA 官方表含) |
| BUG-CMP-002 | 无头 headless 路径在双 GPU 下未实测 | 高 | NOT TESTED(代码级已确认存在) |
| BUG-CMP-003 | BAR1 实况未取证 | 中 | NOT TESTED |
| BUG-CMP-004 | Subsystem ID 历史值不一致(8B04/8804) | 低 | 待复核(不影响匹配) |
| BUG-CMP-005 | OpenCL 不可用 | 信息 | CONFIRMED(上游无此能力) |

## E. 主板与外设
| ID | Bug | 状态 |
|----|-----|------|
| BUG-BRD-001 | 板载音频无 AppleALC → 不可用 | CONFIRMED(配置事实)/影响 NOT TESTED |
| BUG-BRD-002 | USB 非板级映射 | CONFIRMED(配置事实) |
| BUG-BRD-003 | 睡眠/唤醒/重启/关机/NVRAM 全项 | NOT TESTED(L4) |
| BUG-BRD-004 | I219-V | 已工作(用户日常)——记录为 PASS 证据待 L4 复核 |

## F. 系统级
| ID | Bug | 状态 |
|----|-----|------|
| BUG-SYS-001 | 20FPS 桌面(同 P630-001 根因) | CONFIRMED(现象) |
| BUG-SYS-002 | 内核持续报错/泄漏/休眠恢复 | NOT TESTED(L4 日志) |

每个 CONFIRMED 项:根因/修复/回归已在对应文档(02/04/06/07);NOT TESTED 项由 09/12 的流程闭环。
