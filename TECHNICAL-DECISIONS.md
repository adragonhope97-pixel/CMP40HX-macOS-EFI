# TECHNICAL-DECISIONS — 技术决策记录(v1.0)

| # | 决策 | 依据 | 结果 |
|---|------|------|------|
| 1 | EFI 采用"平台定制模板"而非"通用 EFI"发布 | SMBIOS 身份字段属隐私红线,清空后必须由使用者自行生成;不伪造"开箱即用" | 公开版 README 明示限制 |
| 2 | 公开版移除 Intel 核显 DeviceProperties | 核显专用配置属未授权公开信息;移除不破坏 config 合法性 | ocvalidate 零错误;使用者按 Dortania 自补 |
| 3 | 公开版排除所有 bootloader 二进制 | 所用 OpenCore 为定制构建(版本不可证)+ 两个辅助驱动来源不可追溯;供应链原则 | NOTICE 提供官方获取清单 |
| 4 | CMP 40HX model 注入保留在公开版 | 这是项目核心适配内容,且不含隐私 | 路径需使用者按 Docs 复核 |
| 5 | PCI 路径采用 Windows 双证据推导 + 实机复核流程 | PEG1 名称不单独证明 _ADR | 路径 = 候选级;03 脚本复核 |
| 6 | 驱动匹配研究:回退门禁放行 1F0B | install.sh SUPPORTED_IDS(247)不含 CMP SKU,但 ≥0x1E00 回退接受;NVIDIA 官方表含 1F0B | 不需要任何身份伪造 |
| 7 | Subsystem ID 不公开具体值 | 两种历史记录值不一致且未实机复核;遵守"以实测为准" | HARDWARE.md 标注待复核 |
| 8 | 无头计算路径确认存在但未验证 | NVAccel headlessCheck 源码级确认;前提 = Intel IOFramebuffer 存在 | 写入 ROADMAP 前置依赖 |
| 9 | OpenCL 排除在目标外 | 上游栈无 OpenCL 组件 | README 明示 |
| 10 | 内存/Wi-Fi 型号不填写 | 无实测证据,禁止猜测 | HARDWARE.md 标注 BLOCKED |
