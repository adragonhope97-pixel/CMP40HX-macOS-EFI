# BUG-REPORT — Bug 记录(v1.0)

状态:OPEN / FIXED / NOT TESTED / WONTFIX(说明)。

| ID | 严重度 | 描述 | 复现条件 | 根因 | 修复 | 回归 | 状态 |
|----|--------|------|----------|------|------|------|------|
| BUG-EFI-004 | 低 | Lilu 不在 kext 链首 | 始终 | 1401 工具链生成顺序 | 链首重排(待批) | 待 L4 | OPEN |
| BUG-EFI-007 | 中 | HfsPlus/apfs_aligned 来源不可追溯 | 供应链审查 | 定制构建产物 | 公开版排除二进制;私有版另行处理 | — | FIXED(公开范围)/OPEN(私有) |
| BUG-EFI-008 | 中 | OpenCore 为定制构建,版本不可证 | 版本对账 | 1401 工具链 | 升级独立立项 | — | OPEN |
| BUG-EFI-009 | 高 | 板载音频无 AppleALC/layout 注入 | 音频使用 | 基线未含 | AppleALC + layout 试错(待批) | 待 L4 | OPEN |
| BUG-EFI-010 | 中 | USB 为通用映射 | 端口/睡眠场景 | 基线未定制 | 实机采集出 UTBMap(待批) | 待 L4 | OPEN |
| BUG-P630-001 | 高 | 图形加速未生效(桌面约 20FPS、VRAM 报告 14MB) | 桌面日常 | boot-args 含 -igfxvesa 强制 VESA;另与 NullMoth 无头分支存在交叉依赖 | 移除参数(需先确认 26.7.2 CFL framebuffer 存在;救援预案就绪) | 待 L4 | OPEN |
| BUG-CMP-001 | 信息 | 1F0B 不在 NullMoth 615.78.08 提取表 | 门禁审查 | 提取口径排除 CMP SKU | 无需(回退门禁放行;NVIDIA 官方表含) | — | WONTFIX(上游语义) |
| BUG-CMP-002 | 高 | 无头计算路径未实测 | 驱动安装后 | — | 阶段计划 | — | NOT TESTED |
| BUG-CMP-004 | 低 | Subsystem ID 两种历史值 | 复核 | 记录不一致 | 实机复核 | — | OPEN |
| BUG-CMP-005 | 信息 | OpenCL 不可用 | 计算需求 | 上游无组件 | 不适用 | — | WONTFIX(上游边界) |
