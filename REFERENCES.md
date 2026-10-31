# REFERENCES — 参考资料(v1.0)

| # | 名称 | URL | 维护方 | 版本/Commit | 获取日期 | 许可 | 参考内容 | 直接采用 | 修改 | 模块 |
|---|------|-----|--------|-------------|----------|------|----------|----------|------|------|
| 1 | OpenCorePkg | https://github.com/acidanthera/OpenCorePkg | acidanthera | 1.0.8(RELEASE 包) | 2026-10-31 | BSD-3(项目声明) | ocvalidate/官方二进制获取 | 工具与二进制获取指引 | 否 | EFI/发布 |
| 2 | OpenCore Configuration.pdf | https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.pdf | acidanthera | master | 2026-10-31 | 随项目 | 配置项语义(LauncherOption/SecureBootModel 等) | 否(仅查阅) | 否 | config 设计 |
| 3 | Dortania OpenCore Install Guide | https://github.com/dortania/OpenCore-Install-Guide | Dortania | master | 2026-10-31 | CC BY-NC-SA? 以仓库为准 | Coffee Lake 基线方法论 | 否(方法论) | 否 | EFI 设计 |
| 4 | Dortania Coffee Lake 指南 | https://github.com/dortania/OpenCore-Install-Guide/blob/master/config.plist/coffee-lake.md | Dortania | master | 2026-10-31 | 同上 | CFL 平台 ACPI/kext/属性基线 | 对照 | 否 | ACPI/P630 |
| 5 | NullMoth NVIDIA macOS Driver | https://github.com/nullmoth/nvidia-macos-driver | NullMoth Systems | commit ceba63c1(2.6.5) | 2026-10-31 | PolyForm Noncommercial(kexts/plugin)/LGPL(translator)/Mesa(nvk) | 架构、门禁、无头路径 | 研究对象;**未集成其代码** | 否 | 驱动研究 |
| 6 | NullMoth CARD-SUPPORT | https://github.com/nullmoth/nvidia-macos-driver/blob/main/docs/CARD-SUPPORT.md | 同上 | ceba63c1 | 2026-10-31 | 同上 | 物理验证矩阵/无头边界 | 引用短摘录 | 否 | 兼容性 |
| 7 | NullMoth HOW-IT-WORKS | https://github.com/nullmoth/nvidia-macos-driver/blob/main/docs/HOW-IT-WORKS.md | 同上 | ceba63c1 | 2026-10-31 | 同上 | 分层架构/GSP 路径 | 引用 | 否 | 驱动研究 |
| 8 | NullMoth CHANGELOG | https://github.com/nullmoth/nvidia-macos-driver/blob/main/CHANGELOG.md | 同上 | 2.6.5 | 2026-10-31 | 同上 | Turing 用户案例/小 BAR1 修复 | 引用 | 否 | 可行性 |
| 9 | NullMoth Releases | https://github.com/nullmoth/nvidia-macos-driver/releases | 同上 | — | 2026-10-31 | — | 发布形态(1401 app) | 未使用 | 否 | 部署预案 |
| 10 | NVIDIA Open GPU Kernel Modules | https://github.com/NVIDIA/open-gpu-kernel-modules | NVIDIA | main(2026-10 检视) | 2026-10-31 | MIT/GPL(双层,以仓库为准) | Turing GSP 支持 | 否 | 驱动研究 |
| 11 | NVIDIA Linux Driver supportedchips(570.153.02) | https://us.download.nvidia.com/XFree86/Linux-x86_64/570.153.02/README/supportedchips.html | NVIDIA | 570.153.02 | 2026-10-31 | NVIDIA 文档 | **官方表列 "NVIDIA CMP 40HX 1F0B"** | 引用(短摘录) | 否 | 设备支持 |
| 12 | NullMoth GSP 支持表 | 仓库内 nvidia_gsp_ids.json(源自 615.78.08 supported-gpus.json,消费卡子集) | NullMoth/NVIDIA | 615.78.08 | 2026-10-31 | NVIDIA 许可 | 1F0B 不在提取表;回退门禁 | 引用 | 否 | 门禁分析 |
| 13 | 1401 项目 | https://github.com/nullmoth/1401 | NullMoth Systems | 2.6.5 | 2026-10-31 | 同 NullMoth | 安装器形态 | 未使用(研究) | 否 | 部署预案 |
| 14 | pci.ids | https://pci-ids.ucw.cz/ | pciutils 项目 | 2026-10 检视 | 2026-10-31 | GPL/FDL(数据) | 10DE:1F0B = TU106 [CMP 40HX] | 引用 | 否 | 硬件识别 |
| 15 | Dortania USB 定制方法论 | https://dortania.github.io/OpenCore-Post-Install/usb/ | Dortania | master | 2026-10-31 | 同 3 | USBMap 流程 | 方法论 | 否 | USB |

**版权规则遵守声明**:本仓库不复制任何第三方 README/PDF/源码全文;仅使用短摘录并标注出处;随 EFI 分发的 kext 二进制属上游许可范围,来源与许可见 NOTICE;OpenCore 相关二进制未随附,仅提供官方获取链接。
