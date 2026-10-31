# DEVELOPMENT-LOG — 开发过程记录(v1.0)

> 记录原则:只记录真实发生的工作。每阶段附证据位置(私有工程目录名,公开版不含本地路径)。

## 阶段 1:项目启动与硬件识别
- 目标:确认 CMP 40HX 的 PCI 身份。
- 执行:pci.ids 数据库核对 + 用户提供的系统报告;确认 10DE:1F0B = "TU106 [CMP 40HX]"。
- 产物:硬件档案与"实测身份卡"占位表(公开版见 HARDWARE.md)。

## 阶段 2:PCI 路径分析
- 输入:Windows 设备管理器 Location Path(PCIROOT(0)#PCI(0101)#PCI(0000))+ ACPI 路径(_SB.PCI0.PEG1.PEGP)。
- 决策:推导 OpenCore 路径 PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0);保留"实机 IORegistry 复核"步骤。

## 阶段 3:EFI 现状审计
- 执行:config.plist 结构化解析、ocvalidate 双版本、kext/ACPI/Driver 逐项核对。
- 发现(公开可述):音频组件缺失、USB 为通用映射、Lilu 不在链首、两个 bootloader 二进制来源不可追溯。
- 产物:语义审计脚本(efi-audit.sh,12 项检查)。

## 阶段 4:近似案例研究
- 执行:GitHub API 可追溯检索;深入解析同代 Xeon + 现代 OC 案例(其 config.plist 实读)与同主板历史案例。
- 结论:AppleALC + layout-id 注入方式、USB 映射工具链、ACPI 基线的对照结论。

## 阶段 5:配置迭代与名称注入
- 执行:多轮 config 修订(每轮独立备份/差异/回滚),最终在实测确认的 PciRoot 路径注入 model = Data "NVIDIA CMP 40HX"。
- 验证:plistlib + ocvalidate 零错误;自测套件 26/26(含故障注入)。

## 阶段 6:NullMoth 上游研究
- 执行:官方仓库按 commit 固定取证(README/CHANGELOG/CARD-SUPPORT/HOW-IT-WORKS/MULTI-GPU/install.sh/kexts 源码)。
- 关键结论:1F0B 不在 615.78.08 提取表但回退门禁放行;NVIDIA 官方 supportedchips 表列有 CMP 40HX;Turing 有事实用户案例(GTX 1660 Ti)。

## 阶段 7:无头 GPU 研究
- 执行:NVAccel 源码精读,定位 headlessCheck/armHeadlessCheck/headlessDisplayOwner。
- 结论:上游显式支持"无显示头 NVIDIA GPU + 其他 GPU 显示桌面"形态——前提是 Intel 侧存在 IOFramebuffer。

## 阶段 8:P630 显示诊断(未闭环)
- 执行:诊断脚本与取证方案就绪;静态层面发现 -igfxvesa 与低帧率/14MB VRAM 的强关联。
- 状态:根因确认与修复需目标机实测。

## 阶段 9:隐私清理与公开发布(本仓库)
- 执行:EFI 逐文件剥离(SMBIOS 身份清空/核显属性移除/二进制排除)、全树隐私扫描、三语文档、校验和。
- 结果:见 PRIVACY-AUDIT.md 与 EFI-PUBLIC-CONTENT-AUDIT.md。

## 阶段 10:发布
- 状态:见仓库根 GITHUB-PUBLISH-REPORT.md(如实记录到达的步骤)。

## 未解决问题
见 BUG-REPORT.md 的 OPEN 项。
