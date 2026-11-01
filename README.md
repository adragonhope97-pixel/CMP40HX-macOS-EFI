# CMP 40HX EFI — macOS / OpenCore 适配工程(完整文档)

简体中文 | [English](#english) | [繁體中文（臺灣）](#繁體中文臺灣)

> 本 README 即项目完整文档(开发过程 / 规则 / 技术决策 / Bug / 测试 / 隐私审计全部内联)。
> 硬件明细单独成页:[HARDWARE.md](HARDWARE.md)。PCI 路径复核方法:[Docs/pci-path-verification.md](Docs/pci-path-verification.md)。

---

## 一、项目简介

本项目是一个面向 **NVIDIA CMP 40HX** 的 macOS / OpenCore EFI 适配与驱动研究项目，目标是探索 CMP 40HX 在 macOS 环境中的设备识别、驱动初始化和 GPU 计算能力适配。

本项目不做任何优先权宣传；所有结论以分级测试证据为准（L1 静态 / L2 自动化 / L3 外部硬件证据 / L4 目标机实测）。

## 二、项目目标

1. 让 macOS 原生枚举并识别 CMP 40HX（PCI 层）——已完成。
2. 研究 NullMoth NVIDIA macOS Driver 对 Turing / CMP 40HX 的适配路径——源码级研究已完成。
3. 保持平台原有显示 GPU 正常工作，双 GPU 并存——架构已确认（上游无头分支）。
4. 公开一套经过隐私清理、可审查、可复现的 EFI 配置——本仓库。

## 三、硬件平台(摘要)

明细与证据来源见 [HARDWARE.md](HARDWARE.md)。

| 类别 | 型号 | 证据 |
|------|------|------|
| 主板 | ASUS ROG STRIX Z370-F GAMING | 实测环境 |
| CPU | Intel Xeon E-2124G(Coffee Lake-S) | 实测环境 |
| NVIDIA GPU | CMP 40HX — `10DE:1F0B`,Rev `0x00A1` | macOS 系统报告实测 |
| 内存 / Wi-Fi | BLOCKED(无实测证据,不填写) | — |

## 四、CMP 40HX 适配情况

### 4.1 七层状态表(不得混同)

| 层级 | 状态 | 说明 |
|------|------|------|
| 1. PCI 枚举 | ✅ PASS(L4) | 10DE:1F0B 出现在系统信息 → PCI,Link Up |
| 2. 设备名称显示 | ✅ **实机确认** | 系统信息 → PCI 显示 "NVIDIA CMP 40HX"(2026-10-31) |
| 3. NVIDIA 内核驱动(NVRM 等) | ✅ **已安装并加载** | NullMoth 2.6.5 四组件 kmutil 实测(2026-11-01) |
| 4. GSP 固件加载 | ❌ NOT TESTED | 依赖层 3 |
| 5. GPU 初始化 | ❌ NOT TESTED | 依赖层 4 |
| 6. Metal / Vulkan / OpenCL 计算 | ❌ NOT TESTED | 依赖层 5;OpenCL 在上游功能范围内,CMP 40HX 支持程度取决于驱动实现与设备初始化结果 |
| 7. 显示输出 | — | 本卡无显示接口;显示由核显负责 |

### 4.2 设备匹配链(源码级结论)

| 门禁层 | 规则 | 1F0B 结果 |
|--------|------|-----------|
| IOKit 探针 | vendor `0x10DE` + class `0x03` | 命中 |
| install.sh 白名单(247 ID,615.78.08 提取) | 精确 ID | 不含 CMP SKU |
| install.sh 回退门禁 | `≥0x1E00` 即接受 | **放行** |
| NVIDIA 官方 supportedchips(570.153.02) | 官方支持表 | **列名 "NVIDIA CMP 40HX 1F0B"** |

结论:**无需任何身份伪造即可进入安装流程**;Subsystem ID 不参与任何匹配层。

## 五、EFI 文件说明(逐项)

### 5.1 config.plist 关键内容

| 位置 | 内容 | 说明 |
|------|------|------|
| DeviceProperties → `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` | `model = "NVIDIA CMP 40HX"`(Data,15 字节) | 本项目核心注入;路径来自作者机器实测,其他机器必须按 [Docs/pci-path-verification.md](Docs/pci-path-verification.md) 复核 |
| NVRAM → boot-args | `-v debug=0x100 keepsyms=1 igfxonln=1 -igfxvesa revpatch=sbvmm` | 调试 + 平台显示参数(原样保留自验证基线) |
| NVRAM → csr-active-config | `03000000` | SIP 状态(原样保留) |
| PlatformInfo | 机型 `iMac19,1`,身份字段**全空** | 使用者必须自行生成(见安装步骤) |
| Kernel → Quirks | AppleXcpmCfgLock / CustomSMBIOSGuid / DisableIoMapper / DisableRtcChecksum / PanicNoKextDump / PowerTimeoutKernelPanic | Coffee Lake-S Xeon 惯例 |

### 5.2 ACPI(SSDT,6 个)

| 文件 | 作用 |
|------|------|
| SSDT-SBUS.aml | SMBus 控制器补齐 |
| SSDT-EC.aml | 虚拟 EC 设备(桌面机必需) |
| SSDT-MCHC.aml | 内存控制器设备补齐 |
| SSDT-PMC.aml | 300 系 NVRAM/PMC 支持 |
| SSDT-PLUG.aml | CPU XCPM 电源管理 |
| SSDT-USBX.aml | USB 电源属性 |

### 5.3 Kexts(11 个,版本与上游)

| Kext | 版本 | 作用 |
|------|------|------|
| Lilu | 1.7.3 | 补丁框架(必须最先加载于其插件) |
| VirtualSMC / SMCProcessor / SMCSuperIO | 1.3.9 | SMC 仿真与传感器 |
| WhateverGreen | 1.7.2 | 图形补丁框架 |
| RestrictEvents | 1.1.7 | 限制事件修正(revpatch) |
| USBToolBox + UTBDefault | 1.0 | USB 端口映射(通用版) |
| IntelMausiEthernet | 3.0.3 | Intel I219-V 网卡 |
| CtlnaAHCIPort | 341.0.2 | SATA AHCI 端口 |
| XHCI-unsupported | 0.9.2 | XHCI 控制器解锁 |

## 六、安装步骤(逐步)

> 本包是"平台定制模板",不是开箱即用 EFI。缺以下任何一步都无法启动,这是隐私剥离的结果而非缺陷。

1. **生成 SMBIOS**:用 GenSMBIOS 按你的平台生成机型(本项目原机为 `iMac19,1`),把 Serial/MLB/UUID/ROM 填入 `PlatformInfo → Generic`(公开版这些字段为空)。
2. **获取 OpenCore 引导二进制**(本包不含,原因见"隐私清理"):
   - [OpenCore 1.0.8 RELEASE](https://github.com/acidanthera/OpenCorePkg/releases) → `X64/EFI/BOOT/BOOTX64.EFI`、`X64/EFI/OC/OpenCore.efi`、`X64/EFI/OC/Drivers/OpenRuntime.efi`、`X64/EFI/OC/Drivers/ResetNvramEntry.efi`
   - HfsPlus.efi:[OcBinaryData](https://github.com/acidanthera/OcBinaryData) → `Drivers/HfsPlus.efi`
   - Tahoe 300 系平台另需 `apfs_aligned.efi`(来源:OpenCore Legacy Patcher 项目),按需取舍。
3. **核显用户**:自行按 Dortania 指南补 `DeviceProperties` 的核显属性(公开版已按隐私规则剥离)。
4. **组装目录**:`EFI/OC/{config.plist, ACPI/, Kexts/, Drivers/(上面4个)}` + `EFI/BOOT/BOOTX64.EFI`。
5. **校验**:`ocvalidate`(官方发布包 Utilities 内)零错误后再部署。
6. **CMP 40HX 路径复核**:按 [Docs/pci-path-verification.md](Docs/pci-path-verification.md) 在你的机器上确认 `model` 注入路径(每台机器插槽不同)。
7. **部署**:U 盘或 ESP 分区;首次启动建议接核显显示输出、verbose 观察进桌面。
8. **驱动层(可选,独立工程)**:NullMoth 驱动走 `/Library/Extensions + AuxKC`,与 OpenCore 注入无关;其安装与系统级要求(SIP/AMFI/boot-args)见其官方 README,**本项目未包含也未验证**。

## 七、使用限制(逐条)

1. 本包以"作者机器(Coffee Lake-S + Xeon + Z370-F)"为参照;其他平台逐项评估,不可照搬。
2. `model` 注入路径必须按你自己的 IORegistry 复核。
3. 本包**不提供** NVIDIA 驱动;NullMoth 为独立第三方项目,其许可(PolyForm Noncommercial)与系统要求自行评估。
4. OpenCL 在 NullMoth 功能范围内,但 CMP 40HX 上尚未实测;支持程度取决于驱动初始化结果。
5. 公开版不含任何序列号类身份数据——这是隐私剥离的结果,不是疏漏。

### 实机状态速览（2026-11-01 更新，作者机器实测）

| 项目 | 状态 | 等级 |
|------|------|------|
| macOS Tahoe 26.7.2 启动（P630 负责显示） | ✅ 正常进桌面 | L4 |
| CMP 40HX PCI 枚举 | ✅ 10DE:1F0B · Rev A1 · Subsystem 1043:8804 · Link Up | L4 |
| 设备名称显示 | ✅ 系统信息 → PCI 显示 "NVIDIA CMP 40HX" | L4 |
| PCIe 链路 | ✅ Gen1 ×4（设备原生上限，实测） | L4 |
| 核显图形加速 | ⚠️ 未生效（VESA，桌面约 20FPS）——修复方案待批准 | L4 现象已采集 |
| NullMoth 驱动安装(官方 2.6.5 包) | ✅ install.sh 全流程成功(预检/完整性/备份/安装) | L4 |
| 驱动加载(NVRM/NVAccel/NVRMFB/NVRMAGDC) | ✅ 四组件全部加载(kmutil 实测) | L4 |
| NVIDIA 出现在显示设备枚举 | ✅ 系统信息显示 CMP 40HX | L4 |
| GSP 加载 / GPU 初始化 | ⏳ 下轮取证 | — |
| Metal 枚举 / 计算 | NOT TESTED | — |

## 八、兼容性说明

- **已验证可用**:Coffee Lake-S 平台 + Xeon + 核显显示 + CMP 40HX PCI 枚举(作者机器)。
- **理论兼容**:同代 Coffee Lake 台式平台,按第四节逐项对照后使用。
- **不适用**:AMD 平台、笔记本、较旧芯片组——未测试,不承诺。

## 九、已知问题(摘要)

1. 核显图形加速未生效(桌面帧率低)——根因指向显示参数,修复方案在内部决策流程中。
2. 板载音频未适配(缺音频补丁组件)。
3. USB 为通用映射,未做板级端口定制。
4. 驱动层(NullMoth)全部 NOT TESTED。

完整记录见下文"Bug 记录"。

## 十、测试等级与结果

| 等级 | 内容 | 状态 |
|------|------|------|
| L1 静态检查 | plist 解析 / ocvalidate 零错误 / 语义审计 12 项 | ✅ 全部通过 |
| L2 自动化测试 | 工具自测 26 项(含故障注入) | ✅ 26/26 |
| L3 外部硬件证据 | Windows PCI 路径双证据 / NVIDIA 官方支持表 | ✅ 已归档 |
| L4 目标机实测 | 启动 ✅ / PCI 枚举 ✅ / **名称显示 ✅** / 驱动层 · 音频 · USB · 睡眠 ❌ NOT TESTED | 部分 |

**声明:L4 未完成项一律 NOT TESTED,不作为已解决宣称。**

## 十一、开发过程(10 阶段,全部真实发生)

| 阶段 | 内容 | 结果 |
|------|------|------|
| 1 硬件识别 | pci.ids 核对 + 系统报告取证 | 10DE:1F0B 确认 |
| 2 PCI 路径分析 | Windows 双证据 → OpenCore 路径推导 | 候选路径 + 复核方法 |
| 3 EFI 现状审计 | 结构化解析 + 语义审计脚本(12 项) | 发现音频/USB/链首/来源问题 |
| 4 案例研究 | 同代 Xeon 现代 OC 案例(config 实读)+ 同主板历史案例 | 交叉验证 ACPI/Quirks 基线 |
| 5 配置迭代 | 多轮修订,每轮备份/差异/回滚 | model 注入写入实测路径 |
| 6 NullMoth 研究 | HEAD 源码按 commit 固定取证 | 匹配链/门禁/无头路径全解 |
| 7 无头 GPU 研究 | NVAccel 源码精读 | 上游显式支持"无头 + 其他 GPU 显示桌面" |
| 8 显示诊断 | 诊断脚本与取证方案 | 根因指向显示参数,待实机闭环 |
| 9 隐私清理 | 逐文件剥离 + 全树扫描 | 本公开版 |
| 10 发布 | GitHub 新仓库 + Release | 本仓库 |
| 11 NullMoth 源码研究 | HEAD 门禁/无头路径/兼容链全解 | Docs/research/02 |
| 12 EFI 迭代 | Exp-N1 变体部署(NullMoth 要求全集) | Docs/research/04 |
| 13 驱动安装与加载验证 | install.sh 成功 + 四组件加载 | Docs/INSTALL-LOG.md |

## 十二、开发规则(15 条,全程遵守)

1. 不伪造测试结果;所有结论可溯源。
2. 不将 L1/L2/L3 称为 L4 实机验证。
3. 不随意修改无关硬件配置。
4. 不覆盖未经备份的 EFI;原始版本永久保留。
5. 每次修改记录差异(前后值/原因/回滚)。
6. 每个补丁说明原因与影响。
7. 每项结论提供证据。
8. 未验证项目标注 NOT TESTED。
9. 不隐瞒已知 Bug。
10. 不把理论兼容性描述为实际可用。
11. 不泄露用户隐私。
12. 不公开未经授权的硬件信息。
13. 不破坏原始可启动 EFI。
14. 不使用"全球首个"等未经证实的宣传。
15. 不把 PCI 名称显示成功描述为驱动适配完成。

## 十三、技术决策(10 项)

| # | 决策 | 依据 |
|---|------|------|
| 1 | 以"平台定制模板"发布而非"通用 EFI" | SMBIOS 属隐私红线;不伪造开箱即用 |
| 2 | 移除核显 DeviceProperties | 核显专用配置属未授权信息;ocvalidate 复检零错误 |
| 3 | 排除全部 bootloader 二进制 | 所用 OpenCore 为定制构建,版本不可证;供应链原则 |
| 4 | 保留 CMP `model` 注入 | 项目核心内容,无隐私 |
| 5 | 路径 = Windows 双证据推导 + 实机复核流程 | ACPI 节点名不单独证明 _ADR |
| 6 | 匹配研究:回退门禁放行,不改任何身份 | 白名单不含 CMP 但回退 ≥0x1E00 接受;NVIDIA 官方表含 1F0B |
| 7 | Subsystem ID 已定案:1043:8804(Windows PnP + nvidia-smi + macOS IORegistry 三源一致);历史值 0x8B04 标记为错误记录,不再沿用 | 已定案(2026-11-01) |
| 8 | 无头计算写入路线图 | 上游 headlessCheck 源码确认;前置 = Intel IOFramebuffer 存在 |
| 9 | OpenCL:上游功能范围包含,CMP 40HX 未实测——状态 NOT TESTED | 依据上游 README 修正(2026-11-01) |
| 10 | 内存/Wi-Fi 不填写 | 无实测证据,禁止猜测 |

## 十四、隐私清理明细

| 项 | 处理 |
|----|------|
| SMBIOS 身份(Serial/MLB/UUID/ROM) | 字段保留、**值清空**;使用者自行生成 |
| 核显 DeviceProperties | **整条移除**(核显用户按 Dortania 自补) |
| bootloader 二进制 | **全部排除**(官方渠道获取,见安装步骤) |
| 全树扫描 | 用户名/本地路径/网络信息/未验证硬件字面值:**零命中** |
| ACPI/kext 二进制 | ASCII 扫描零隐私命中 |

## 十五、Bug 记录(完整表)

| ID | 严重度 | 描述 | 根因 | 修复 | 状态 |
|----|--------|------|------|------|------|
| BUG-EFI-004 | 低 | Lilu 不在 kext 链首 | 工具链生成顺序 | 链首重排 | OPEN |
| BUG-EFI-007 | 中 | HfsPlus 等二进制来源不可追溯 | 定制构建产物 | 公开版排除二进制 | FIXED(公开范围) |
| BUG-EFI-008 | 中 | OpenCore 为定制构建,版本不可证 | 1401 工具链 | 升级独立立项 | OPEN |
| BUG-EFI-009 | 高 | 板载音频未适配 | 基线未含音频组件 | AppleALC + layout 试错 | OPEN |
| BUG-EFI-010 | 中 | USB 为通用映射 | 基线未定制 | 实机采集出映射 | OPEN |
| BUG-P630-001 | 高 | 核显加速未生效(桌面约 20FPS) | boot-args 强制 VESA;与上游无头分支存在交叉依赖 | 移除该参数(需前置确认) | OPEN |
| BUG-CMP-001 | 信息 | 1F0B 不在提取表 | 提取口径排除 CMP | 无需修复(回退放行) | WONTFIX |
| BUG-CMP-002 | 高 | 无头计算未实测 | 驱动未安装 | 阶段计划 | NOT TESTED |
| BUG-CMP-004 | 低 | Subsystem 两种历史值(8B04/8804) | 记录不一致 | 双侧实测定案 0x8804 | — | RESOLVED |
| BUG-CMP-005 | 中 | OpenCL 支持未验证(上游功能范围包含) | 设备初始化未完成 | 阶段 B4 验证 | — | NOT TESTED |

## 十六、参考资料

| 名称 | 链接 | 用途 |
|------|------|------|
| OpenCorePkg(1.0.8) | https://github.com/acidanthera/OpenCorePkg | ocvalidate / 官方二进制 |
| OpenCore Configuration.pdf | https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.pdf | 配置项语义 |
| Dortania Install Guide / Coffee Lake | https://github.com/dortania/OpenCore-Install-Guide | 平台基线方法论 |
| NullMoth NVIDIA macOS Driver(2.6.5) | https://github.com/nullmoth/nvidia-macos-driver | 驱动研究对象(未集成其代码) |
| NullMoth CARD-SUPPORT / HOW-IT-WORKS / CHANGELOG | 见仓库 docs/ | 验证矩阵 / 架构 / Turing 案例 |
| NVIDIA Open GPU Kernel Modules | https://github.com/NVIDIA/open-gpu-kernel-modules | Turing GSP 支持 |
| NVIDIA supportedchips(570.153.02) | https://us.download.nvidia.com/XFree86/Linux-x86_64/570.153.02/README/supportedchips.html | 官方表含 CMP 40HX |
| 1401 项目 | https://github.com/nullmoth/1401 | 安装器形态 |
| pci.ids | https://pci-ids.ucw.cz/ | 10DE:1F0B = TU106 [CMP 40HX] |

第三方 kext 上游与许可:见 [NOTICE](NOTICE)。

## 十七、许可证

项目文件:MIT([LICENSE](LICENSE))。随包分发的 kext 二进制归其上游所有,各自许可见 NOTICE。**禁止**:删除许可与来源声明后再分发。

## 十八、免责声明

本项目仅供学习研究。Hackintosh 依 Apple EULA 属灰色领域,使用风险自负;作者不对任何硬件损坏、数据丢失或违反 EULA 的后果负责。本项目与 Apple、NVIDIA、ASUS 无任何关联。

---

## English

### Introduction

This project explores macOS / OpenCore EFI adaptation and driver compatibility for the NVIDIA CMP 40HX, focusing on device identification, driver initialization, and GPU computing capabilities. No priority claims are made; every conclusion is backed by graded test evidence (L1 static / L2 automated / L3 external hardware evidence / L4 target-machine testing).

### Goals

1. Native PCI enumeration and identification of the CMP 40HX on macOS — done.
2. Research the NullMoth NVIDIA macOS Driver path for Turing / CMP 40HX — source-level research done.
3. Keep the platform's existing display GPU working — dual-GPU coexistence — architecture confirmed.
4. Publish a privacy-cleaned, reviewable, reproducible EFI configuration — this repository.

### Hardware Platform (summary)

Full details and evidence: [HARDWARE.md](HARDWARE.md).

| Category | Model | Evidence |
|----------|-------|----------|
| Motherboard | ASUS ROG STRIX Z370-F GAMING | verified environment |
| CPU | Intel Xeon E-2124G (Coffee Lake-S) | verified environment |
| NVIDIA GPU | CMP 40HX — `10DE:1F0B`, Rev `0x00A1` | measured on target machine |
| Memory / Wi-Fi | BLOCKED (no measurement evidence; left blank) | — |

### CMP 40HX Adaptation Status

Seven-layer status (layers must not be conflated):

| Layer | Status |
|-------|--------|
| 1. PCI enumeration | ✅ PASS (L4) |
| 2. Device name display | ✅ **confirmed on machine** | System Information → PCI shows "NVIDIA CMP 40HX" (2026-10-31) |
| 3. NVIDIA kernel driver (NVRM etc.) | ✅ **installed & loaded** | NullMoth 2.6.5, four components via kmutil (2026-11-01) |
| 4. GSP firmware load | ❌ NOT TESTED |
| 5. GPU init | ❌ NOT TESTED |
| 6. Metal / Vulkan / OpenCL compute | ❌ NOT TESTED — OpenCL is in the upstream feature scope; actual support depends on driver implementation and device init results |
| 7. Display output | — (card has no outputs; iGPU handles display) |

Device matching chain (source-level): IOKit probe matches vendor `0x10DE` + class `0x03` → hit; the installer whitelist (247 IDs) excludes CMP SKUs; the fallback gate (`≥0x1E00`) accepts this card; NVIDIA's official supported-chips table lists “NVIDIA CMP 40HX 1F0B”. **No identity spoofing is required anywhere.**

### EFI Contents (file by file)

config.plist key items:

| Location | Content |
|----------|---------|
| DeviceProperties → `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` | `model = "NVIDIA CMP 40HX"` (Data) — core injection; path verified on the author's machine, re-verify on yours per Docs/pci-path-verification.md |
| NVRAM → boot-args | `-v debug=0x100 keepsyms=1 igfxonln=1 -igfxvesa revpatch=sbvmm` (kept from the verified baseline) |
| NVRAM → csr-active-config | `03000000` |
| PlatformInfo | model `iMac19,1`, identity fields **empty** |
| Kernel → Quirks | AppleXcpmCfgLock / CustomSMBIOSGuid / DisableIoMapper / DisableRtcChecksum / PanicNoKextDump / PowerTimeoutKernelPanic |

ACPI SSDTs: SSDT-SBUS (SMBus), SSDT-EC (virtual EC), SSDT-MCHC (memory controller), SSDT-PMC (NVRAM), SSDT-PLUG (CPU XCPM), SSDT-USBX (USB power).

Kexts: Lilu 1.7.3 (patch framework), VirtualSMC + SMCProcessor + SMCSuperIO 1.3.9, WhateverGreen 1.7.2, RestrictEvents 1.1.7, USBToolBox + UTBDefault 1.0, IntelMausiEthernet 3.0.3 (I219-V), CtlnaAHCIPort 341.0.2, XHCI-unsupported 0.9.2.

**No OpenCore / bootloader binaries are included** (provenance requirements — see Privacy section and NOTICE).

### Installation Steps

This is a “platform-specific template”, not a ready-to-boot EFI. Skipping any step below will prevent booting; that is the result of privacy stripping, not a defect.

1. Generate your own SMBIOS (GenSMBIOS) and fill `PlatformInfo → Generic` (empty in this package).
2. Get OpenCore binaries from the official 1.0.8 release: `BOOTX64.EFI`, `OpenCore.efi`, `OpenRuntime.efi`, `ResetNvramEntry.efi`; plus `HfsPlus.efi` from OcBinaryData. Tahoe/300-series may additionally need `apfs_aligned.efi` (OpenCore Legacy Patcher).
3. iGPU users: add your own framebuffer properties per Dortania (stripped here for privacy).
4. Assemble `EFI/OC/{config.plist, ACPI/, Kexts/, Drivers/}` + `EFI/BOOT/BOOTX64.EFI`.
5. Validate with `ocvalidate` (zero errors) before deploying.
6. Re-verify the CMP 40HX `model` path on YOUR machine (Docs/pci-path-verification.md).
7. Deploy to USB/ESP; first boot on the iGPU display, verbose mode.
8. Driver layer (optional, separate effort): NullMoth installs into /Library/Extensions + AuxKC and has its own system requirements — see its official README; not included or verified here.

### Usage Restrictions

1. Authored against Coffee Lake-S + Xeon + Z370-F; evaluate other platforms item by item.
2. Re-verify the injection path on your own hardware.
3. No NVIDIA driver is bundled; NullMoth is a separate third-party project (PolyForm Noncommercial license — evaluate yourself).
4. OpenCL is listed in the NullMoth feature scope but is unverified on the CMP 40HX; actual support depends on driver init results.
5. The package contains no identity data by design.

### Live Machine Status (updated 2026-11-01, measured on the author's machine)

| Item | Status | Level |
|------|--------|-------|
| macOS Tahoe 26.7.2 boot (P630 display) | ✅ boots to desktop | L4 |
| CMP 40HX PCI enumeration | ✅ 10DE:1F0B · Rev A1 · Subsystem 1043:8804 · Link Up | L4 |
| Device name display | ✅ System Information → PCI shows "NVIDIA CMP 40HX" | L4 |
| PCIe link | ✅ Gen1 ×4 (device-native maximum, measured) | L4 |
| iGPU acceleration | ⚠️ not working (VESA, ~20 FPS) — fix pending approval | L4 symptom captured |
| NullMoth driver install (official 2.6.5 package) | ✅ install.sh full flow succeeded (preflight/integrity/backup/install) | L4 |
| Driver load (NVRM/NVAccel/NVRMFB/NVRMAGDC) | ✅ all four components loaded (kmutil) | L4 |
| NVIDIA in display enumeration | ✅ System Information shows CMP 40HX | L4 |
| GSP load / GPU init | ⏳ next evidence round | — |
| Metal enumeration / compute | NOT TESTED | — |

### Compatibility

Verified working: Coffee Lake-S + Xeon + iGPU display + CMP 40HX PCI enumeration (author's machine). Theoretically compatible: same-generation Coffee Lake desktops after item-by-item review. Not applicable: AMD platforms, laptops, older chipsets — untested.

### Known Issues (summary)

1. iGPU acceleration not working (low desktop FPS) — display flag identified, fix pending decision.
2. Onboard audio not adapted (no audio patch component).
3. USB uses a generic mapping, not a board-specific one.
4. Driver layer (NullMoth) fully NOT TESTED.

Full records in the Bug Records section below.

### Testing Levels & Results

| Level | Scope | Status |
|-------|-------|--------|
| L1 static | plist parse / ocvalidate zero errors / 12-item semantic audit | ✅ |
| L2 automated | 26-item self-test incl. fault injection | ✅ 26/26 |
| L3 external evidence | Windows PCI dual evidence / NVIDIA official table | ✅ archived |
| L4 on-machine | boot ✅ / PCI enumeration ✅ / **name display ✅** / driver · audio · USB · sleep ❌ NOT TESTED | partial |

**Statement: unfinished L4 items are NOT TESTED and are never claimed as solved.**

### Development Process (10 real stages)

| Stage | Result |
|-------|--------|
| 1 Hardware identification | 10DE:1F0B confirmed (pci.ids + system report) |
| 2 PCI path analysis | candidate path + re-verification method |
| 3 EFI audit | 12-item semantic audit; audio/USB/order/provenance findings |
| 4 Case studies | same-generation Xeon modern-OC case config read; same-board legacy case |
| 5 Config iteration | multiple revisions with backup/diff/rollback; model injection landed |
| 6 NullMoth research | HEAD-pinned source study: matching chain / gates / headless path |
| 7 Headless GPU research | upstream explicitly supports “headless NVIDIA GPU + another GPU driving the desktop” |
| 8 Display diagnostics | scripts ready; root cause points to the display flag; on-machine closure pending |
| 9 Privacy cleaning | file-by-file stripping + full-tree scan → this release |
| 10 Publishing | this repository |

### Development Rules (15)

1. Never fabricate test results. 2. Never call L1/L2/L3 an L4 verification. 3. Never touch unrelated hardware config. 4. Never overwrite an unbacked-up EFI. 5. Record a diff for every change. 6. Justify every patch. 7. Back every conclusion with evidence. 8. Mark unverified items NOT TESTED. 9. Never hide known bugs. 10. Never present theoretical compatibility as working. 11. Never leak user privacy. 12. Never publish unauthorized hardware info. 13. Never break the original bootable EFI. 14. No unverified “world first” claims. 15. Never present a PCI name change as driver adaptation.

### Technical Decisions (10)

| # | Decision | Basis |
|---|----------|-------|
| 1 | Publish as a platform-specific template, not a universal EFI | SMBIOS is a privacy red line; no fake “works out of the box” |
| 2 | Remove iGPU DeviceProperties | unauthorized iGPU-specific info; ocvalidate re-check clean |
| 3 | Exclude all bootloader binaries | custom-built OpenCore, version unverifiable; supply-chain principle |
| 4 | Keep the CMP `model` injection | core adaptation content, no privacy |
| 5 | Path = Windows dual evidence + on-machine re-verification | ACPI node name alone does not prove `_ADR` |
| 6 | Matching research: fallback gate admits 1F0B; no identity edits | whitelist lacks CMP but NVIDIA official table includes it |
| 7 | Subsystem ID resolved: 1043:8804 (Windows PnP + nvidia-smi + macOS IORegistry, triple-source); historical value 0x8B04 marked as an error record | resolved (2026-11-01) |
| 8 | Headless compute on the roadmap | upstream headlessCheck confirmed; prerequisite = Intel IOFramebuffer present |
| 9 | OpenCL: included in the upstream feature scope, unverified on the CMP 40HX — status NOT TESTED | corrected per upstream README (2026-11-01) |
| 10 | Memory/Wi-Fi left blank | no measurement evidence; guessing forbidden |

### Privacy Cleaning Details

| Item | Action |
|------|--------|
| SMBIOS identity (Serial/MLB/UUID/ROM) | fields kept, **values blanked** |
| iGPU DeviceProperties | **entry removed** |
| Bootloader binaries | **all excluded** (official channels documented) |
| Full-tree scan | usernames / local paths / network info / unverified hardware literals: **zero hits** |
| ACPI / kext binaries | ASCII scan: zero privacy hits |

### Bug Records (full)

| ID | Severity | Description | Root cause | Fix | Status |
|----|----------|-------------|-----------|-----|--------|
| BUG-EFI-004 | low | Lilu not first in kext order | toolchain ordering | reorder | OPEN |
| BUG-EFI-007 | med | HfsPlus etc. provenance unverifiable | custom build output | binaries excluded from public | FIXED (public scope) |
| BUG-EFI-008 | med | OpenCore is a custom build, version unverifiable | 1401 toolchain | upgrade as separate project | OPEN |
| BUG-EFI-009 | high | onboard audio not adapted | baseline lacks audio component | AppleALC + layout trials | OPEN |
| BUG-EFI-010 | med | USB generic mapping | baseline not customized | on-machine port capture | OPEN |
| BUG-P630-001 | high | iGPU acceleration not working (~20 FPS) | boot-args force VESA; interplay with upstream headless path | remove flag (precondition first) | OPEN |
| BUG-CMP-001 | info | 1F0B not in extraction table | extraction excludes CMP SKUs | none needed (fallback admits) | WONTFIX |
| BUG-CMP-002 | high | headless compute untested | driver not installed | staged plan | NOT TESTED |
| BUG-CMP-004 | low | two historical Subsystem values (8B04/8804) | record inconsistency | resolved to 0x8804 by dual-side measurement | — | RESOLVED |
| BUG-CMP-005 | med | OpenCL support unverified (listed in upstream scope) | device init not completed | stage B4 validation | — | NOT TESTED |

### References

OpenCorePkg (1.0.8) — acidanthera; OpenCore Configuration.pdf; Dortania Install Guide / Coffee Lake guide; NullMoth NVIDIA macOS Driver (2.6.5) incl. CARD-SUPPORT / HOW-IT-WORKS / CHANGELOG / Releases; NVIDIA Open GPU Kernel Modules; NVIDIA supportedchips (570.153.02) — lists “NVIDIA CMP 40HX 1F0B”; 1401 project; pci.ids. Third-party kext upstreams and licenses: NOTICE.

### Research Documents

Docs/research/01 Windows hardware forensics · 02 NullMoth source audit · 03 CMP 40HX adaptation analysis · 04 Metal implementation plan · 09 EFI provenance audit · 10 Picker audit; Docs/BUG-DETECTION-MATRIX.md · BUG-FIX-LOG.md · INSTALL-LOG.md

### License

Project files: MIT (LICENSE). Bundled kext binaries belong to their upstream authors, licenses listed in NOTICE. **Do not** redistribute after removing license/attribution notices.

### Disclaimer

For study and research only. Hackintoshing sits in a gray area of Apple's EULA; use at your own risk. The authors are not responsible for hardware damage, data loss, or EULA violations. Not affiliated with Apple, NVIDIA, or ASUS.

---

## 繁體中文（臺灣）

### 專案簡介

本專案是一個面向 **NVIDIA CMP 40HX** 的 macOS／OpenCore EFI 適配與驅動研究專案，旨在探索 CMP 40HX 在 macOS 環境中的裝置識別、驅動初始化與 GPU 運算能力適配。本專案不做任何優先權宣傳；所有結論以分級測試證據為準（L1 靜態／L2 自動化／L3 外部硬體證據／L4 目標機實測）。

### 專案目標

1. 讓 macOS 原生列舉並識別 CMP 40HX（PCI 層）——已完成。
2. 研究 NullMoth NVIDIA macOS Driver 對 Turing／CMP 40HX 的適配路徑——原始碼級研究已完成。
3. 保持平台原有顯示 GPU 正常運作，雙 GPU 並存——架構已確認（上游無頭分支）。
4. 公開一套經過隱私清理、可審查、可重現的 EFI 設定——本儲存庫。

### 硬體平台（摘要）

明細與證據來源見 [HARDWARE.md](HARDWARE.md)。

| 類別 | 型號 | 證據 |
|------|------|------|
| 主機板 | ASUS ROG STRIX Z370-F GAMING | 實測環境 |
| CPU | Intel Xeon E-2124G（Coffee Lake-S） | 實測環境 |
| NVIDIA GPU | CMP 40HX — `10DE:1F0B`，Rev `0x00A1` | macOS 系統資訊實測 |
| 記憶體／Wi-Fi | BLOCKED（無實測證據，不填寫） | — |

### CMP 40HX 適配情況

#### 七層狀態表（不得混同）

| 層級 | 狀態 | 說明 |
|------|------|------|
| 1. PCI 列舉 | ✅ PASS（L4） | 10DE:1F0B 出現在系統資訊 → PCI，Link Up |
| 2. 裝置名稱顯示 | ✅ **實機確認** | 系統資訊 → PCI 顯示 "NVIDIA CMP 40HX"（2026-10-31） |
| 3. NVIDIA 核心驅動（NVRM 等） | ✅ **已安裝並載入** | NullMoth 2.6.5 四元件 kmutil 實測（2026-11-01） |
| 4. GSP 韌體載入 | ❌ NOT TESTED | 依賴層 3 |
| 5. GPU 初始化 | ❌ NOT TESTED | 依賴層 4 |
| 6. Metal／Vulkan／OpenCL 運算 | ❌ NOT TESTED | 依賴層 5；OpenCL 在上游功能範圍內，CMP 40HX 支援程度取決於驅動實作與裝置初始化結果 |
| 7. 顯示輸出 | — | 本卡無顯示介面；顯示由內顯負責 |

#### 裝置匹配鏈（原始碼級結論）

| 門檻層 | 規則 | 1F0B 結果 |
|--------|------|-----------|
| IOKit 探針 | vendor `0x10DE` + class `0x03` | 命中 |
| install.sh 白名單（247 ID，615.78.08 提取） | 精確 ID | 不含 CMP SKU |
| install.sh 回退門檻 | `≥0x1E00` 即接受 | **放行** |
| NVIDIA 官方 supportedchips（570.153.02） | 官方支援表 | **列名 "NVIDIA CMP 40HX 1F0B"** |

結論：**無需任何身分偽造即可進入安裝流程**；Subsystem ID 不參與任何匹配層。

### EFI 檔案說明（逐項）

#### config.plist 關鍵內容

| 位置 | 內容 | 說明 |
|------|------|------|
| DeviceProperties → `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` | `model = "NVIDIA CMP 40HX"`（Data，15 位元組） | 本專案核心注入；路徑來自作者機器實測，其他機器必須按 [Docs/pci-path-verification.md](Docs/pci-path-verification.md) 複核 |
| NVRAM → boot-args | `-v debug=0x100 keepsyms=1 igfxonln=1 -igfxvesa revpatch=sbvmm` | 除錯 + 平台顯示參數（原樣保留自驗證基線） |
| NVRAM → csr-active-config | `03000000` | SIP 狀態（原樣保留） |
| PlatformInfo | 機型 `iMac19,1`，身分欄位**全空** | 使用者必須自行產生（見安裝步驟） |
| Kernel → Quirks | AppleXcpmCfgLock／CustomSMBIOSGuid／DisableIoMapper／DisableRtcChecksum／PanicNoKextDump／PowerTimeoutKernelPanic | Coffee Lake-S Xeon 慣例 |

#### ACPI（SSDT，6 個）

| 檔案 | 作用 |
|------|------|
| SSDT-SBUS.aml | SMBus 控制器補齊 |
| SSDT-EC.aml | 虛擬 EC 裝置（桌面機必需） |
| SSDT-MCHC.aml | 記憶體控制器裝置補齊 |
| SSDT-PMC.aml | 300 系 NVRAM／PMC 支援 |
| SSDT-PLUG.aml | CPU XCPM 電源管理 |
| SSDT-USBX.aml | USB 電源屬性 |

#### Kexts（11 個，版本與上游）

| Kext | 版本 | 作用 |
|------|------|------|
| Lilu | 1.7.3 | 補丁框架（必須先於其外掛載入） |
| VirtualSMC／SMCProcessor／SMCSuperIO | 1.3.9 | SMC 模擬與感測器 |
| WhateverGreen | 1.7.2 | 圖形補丁框架 |
| RestrictEvents | 1.1.7 | 限制事件修正（revpatch） |
| USBToolBox + UTBDefault | 1.0 | USB 埠映射（通用版） |
| IntelMausiEthernet | 3.0.3 | Intel I219-V 網卡 |
| CtlnaAHCIPort | 341.0.2 | SATA AHCI 埠 |
| XHCI-unsupported | 0.9.2 | XHCI 控制器解鎖 |

### 安裝步驟（逐步）

> 本包是「平台定制範本」，不是開箱即用 EFI。缺以下任何一步都無法啟動，這是隱私移除的結果而非缺陷。

1. **產生 SMBIOS**：用 GenSMBIOS 依你的平台產生機型（原作者機器為 `iMac19,1`），把 Serial／MLB／UUID／ROM 填入 `PlatformInfo → Generic`（公開版這些欄位為空）。
2. **取得 OpenCore 引導二進位檔**（本包不含，原因見「隱私清理」）：
   - [OpenCore 1.0.8 RELEASE](https://github.com/acidanthera/OpenCorePkg/releases) → `X64/EFI/BOOT/BOOTX64.EFI`、`X64/EFI/OC/OpenCore.efi`、`X64/EFI/OC/Drivers/OpenRuntime.efi`、`X64/EFI/OC/Drivers/ResetNvramEntry.efi`
   - HfsPlus.efi：[OcBinaryData](https://github.com/acidanthera/OcBinaryData) → `Drivers/HfsPlus.efi`
   - Tahoe 300 系平台另需 `apfs_aligned.efi`（來源：OpenCore Legacy Patcher 專案），按需取捨。
3. **內顯使用者**：自行依 Dortania 指南補 `DeviceProperties` 的內顯屬性（公開版已按隱私規則移除）。
4. **組裝目錄**：`EFI/OC/{config.plist, ACPI/, Kexts/, Drivers/（上面4個）}` + `EFI/BOOT/BOOTX64.EFI`。
5. **校驗**：`ocvalidate`（官方發布包 Utilities 內）零錯誤後再部署。
6. **CMP 40HX 路徑複核**：按 [Docs/pci-path-verification.md](Docs/pci-path-verification.md) 在你的機器上確認 `model` 注入路徑（每台機器插槽不同）。
7. **部署**：USB 隨身碟或 ESP 分割區；首次啟動建議接內顯輸出、verbose 觀察進桌面。
8. **驅動層（可選，獨立工程）**：NullMoth 驅動走 `/Library/Extensions + AuxKC`，與 OpenCore 注入無關；其安裝與系統級要求（SIP／AMFI／boot-args）見其官方 README，**本專案未包含也未驗證**。

### 使用限制（逐條）

1. 本包以「作者機器（Coffee Lake-S + Xeon + Z370-F）」為參照；其他平台逐項評估，不可照搬。
2. `model` 注入路徑必須按你自己的 IORegistry 複核。
3. 本包**不提供** NVIDIA 驅動；NullMoth 為獨立第三方專案，其授權（PolyForm Noncommercial）與系統要求自行評估。
4. OpenCL 在 NullMoth 功能範圍內，但 CMP 40HX 上尚未實測；支援程度取決於驅動初始化結果。
5. 公開版不含任何序號類身分資料——這是隱私移除的結果，不是疏漏。

### 實機狀態速覽（2026-11-01 更新，作者機器實測）

| 項目 | 狀態 | 等級 |
|------|------|------|
| macOS Tahoe 26.7.2 啟動（P630 負責顯示） | ✅ 正常進桌面 | L4 |
| CMP 40HX PCI 列舉 | ✅ 10DE:1F0B · Rev A1 · Subsystem 1043:8804 · Link Up | L4 |
| 裝置名稱顯示 | ✅ 系統資訊 → PCI 顯示 "NVIDIA CMP 40HX" | L4 |
| PCIe 連結 | ✅ Gen1 ×4（裝置原生上限，實測） | L4 |
| 內顯圖形加速 | ⚠️ 未生效（VESA，桌面約 20FPS）——修復方案待批准 | L4 現象已採集 |
| NullMoth 驅動安裝（官方 2.6.5 包） | ✅ install.sh 全流程成功（預檢／完整性／備份／安裝） | L4 |
| 驅動載入（NVRM／NVAccel／NVRMFB／NVRMAGDC） | ✅ 四元件全部載入（kmutil 實測） | L4 |
| NVIDIA 出現在顯示裝置列舉 | ✅ 系統資訊顯示 CMP 40HX | L4 |
| GSP 載入／GPU 初始化 | ⏳ 下輪取證 | — |
| Metal 列舉／運算 | NOT TESTED | — |

### 相容性說明

- **已驗證可用**：Coffee Lake-S 平台 + Xeon + 內顯顯示 + CMP 40HX PCI 列舉（作者機器）。
- **理論相容**：同代 Coffee Lake 桌面平台，按第四節逐項對照後使用。
- **不適用**：AMD 平台、筆記型電腦、較舊晶片組——未測試，不承諾。

### 已知問題（摘要）

1. 內顯圖形加速未生效（桌面影格率低）——根因指向顯示參數，修復方案在內部決策流程中。
2. 板載音效未適配（缺音效補丁元件）。
3. USB 為通用映射，未做板級埠定制。
4. 驅動層（NullMoth）全部 NOT TESTED。

完整記錄見下文「Bug 記錄」。

### 測試等級與結果

| 等級 | 內容 | 狀態 |
|------|------|------|
| L1 靜態檢查 | plist 解析／ocvalidate 零錯誤／語義稽核 12 項 | ✅ 全部通過 |
| L2 自動化測試 | 工具自測 26 項（含故障注入） | ✅ 26/26 |
| L3 外部硬體證據 | Windows PCI 路徑雙證據／NVIDIA 官方支援表 | ✅ 已歸檔 |
| L4 目標機實測 | 啟動 ✅／PCI 列舉 ✅／**名稱顯示 ✅**／驅動層 · 音效 · USB · 睡眠 ❌ NOT TESTED | 部分 |

**聲明：L4 未完成項一律 NOT TESTED，不作為已解決宣稱。**

### 專案開發過程（10 階段，全部真實發生）

| 階段 | 內容 | 結果 |
|------|------|------|
| 1 硬體識別 | pci.ids 核對 + 系統報告取證 | 10DE:1F0B 確認 |
| 2 PCI 路徑分析 | Windows 雙證據 → OpenCore 路徑推導 | 候選路徑 + 複核方法 |
| 3 EFI 現況稽核 | 結構化解析 + 語義稽核腳本（12 項） | 發現音效／USB／鏈首／來源問題 |
| 4 案例研究 | 同代 Xeon 現代 OC 案例（config 實讀）+ 同主機板歷史案例 | 交叉驗證 ACPI／Quirks 基線 |
| 5 設定迭代 | 多輪修訂，每輪備份／差異／回滾 | model 注入寫入實測路徑 |
| 6 NullMoth 研究 | HEAD 原始碼按 commit 固定取證 | 匹配鏈／門檻／無頭路徑全解 |
| 7 無頭 GPU 研究 | NVAccel 原始碼精讀 | 上游顯式支援「無顯示頭 NVIDIA GPU + 其他 GPU 顯示桌面」 |
| 8 顯示診斷 | 診斷腳本與取證方案 | 根因指向顯示參數，待實機閉環 |
| 9 隱私清理 | 逐檔案移除 + 全樹掃描 | 本公開版 |
| 10 發布 | GitHub 新儲存庫 + Release | 本儲存庫 |

### 開發規則（15 條，全程遵守）

1. 不偽造測試結果；所有結論可溯源。 2. 不將 L1/L2/L3 稱為 L4 實機驗證。 3. 不隨意修改無關硬體配置。 4. 不覆蓋未經備份的 EFI；原始版本永久保留。 5. 每次修改記錄差異（前後值／原因／回滾）。 6. 每個補丁說明原因與影響。 7. 每項結論提供證據。 8. 未驗證項目標註 NOT TESTED。 9. 不隱瞞已知 Bug。 10. 不把理論相容性描述為實際可用。 11. 不洩漏使用者隱私。 12. 不公開未經授權的硬體資訊。 13. 不破壞原始可啟動 EFI。 14. 不使用「全球首個」等未經證實的宣傳。 15. 不把 PCI 名稱顯示成功描述為驅動適配完成。

### 技術決策（10 項）

| # | 決策 | 依據 |
|---|------|------|
| 1 | 以「平台定制範本」發布而非「通用 EFI」 | SMBIOS 屬隱私紅線；不偽造開箱即用 |
| 2 | 移除內顯 DeviceProperties | 內顯專用設定屬未授權資訊；ocvalidate 複檢零錯誤 |
| 3 | 排除全部 bootloader 二進位檔 | 所用 OpenCore 為定制構建，版本不可證；供應鏈原則 |
| 4 | 保留 CMP `model` 注入 | 專案核心內容，無隱私 |
| 5 | 路徑 = Windows 雙證據推導 + 實機複核流程 | ACPI 節點名不單獨證明 _ADR |
| 6 | 匹配研究：回退門檻放行，不改任何身分 | 白名單不含 CMP 但回退 ≥0x1E00 接受；NVIDIA 官方表含 1F0B |
| 7 | Subsystem ID 已定案：1043:8804（Windows PnP + nvidia-smi + macOS IORegistry 三源一致）；歷史值 0x8B04 標記為錯誤記錄，不再沿用 | 已定案（2026-11-01） |
| 8 | 無頭運算寫入路線圖 | 上游 headlessCheck 原始碼確認；前置 = Intel IOFramebuffer 存在 |
| 9 | OpenCL：上游功能範圍包含，CMP 40HX 未實測——狀態 NOT TESTED | 依據上游 README 修正（2026-11-01） |
| 10 | 記憶體／Wi-Fi 不填寫 | 無實測證據，禁止猜測 |

### 隱私清理明細

| 項目 | 處理 |
|------|------|
| SMBIOS 身分（Serial／MLB／UUID／ROM） | 欄位保留、**值清空**；使用者自行產生 |
| 內顯 DeviceProperties | **整條移除**（內顯使用者依 Dortania 自補） |
| bootloader 二進位檔 | **全部排除**（官方管道取得，見安裝步驟） |
| 全樹掃描 | 使用者名稱／本地路徑／網路資訊／未驗證硬體字面值：**零命中** |
| ACPI／kext 二進位檔 | ASCII 掃描零隱私命中 |

### Bug 記錄（完整表）

| ID | 嚴重度 | 描述 | 根因 | 修復 | 狀態 |
|----|--------|------|------|------|------|
| BUG-EFI-004 | 低 | Lilu 不在 kext 鏈首 | 工具鏈產生順序 | 鏈首重排 | OPEN |
| BUG-EFI-007 | 中 | HfsPlus 等二進位檔來源不可追溯 | 定制構建產物 | 公開版排除二進位檔 | FIXED（公開範圍） |
| BUG-EFI-008 | 中 | OpenCore 為定制構建，版本不可證 | 1401 工具鏈 | 升級獨立立項 | OPEN |
| BUG-EFI-009 | 高 | 板載音效未適配 | 基線未含音效元件 | AppleALC + layout 試錯 | OPEN |
| BUG-EFI-010 | 中 | USB 為通用映射 | 基線未定制 | 實機採集出映射 | OPEN |
| BUG-P630-001 | 高 | 內顯加速未生效（桌面約 20FPS） | boot-args 強制 VESA；與上游無頭分支存在交叉依賴 | 移除該參數（需前置確認） | OPEN |
| BUG-CMP-001 | 資訊 | 1F0B 不在提取表 | 提取口徑排除 CMP | 無需修復（回退放行） | WONTFIX |
| BUG-CMP-002 | 高 | 無頭運算未實測 | 驅動未安裝 | 階段計畫 | NOT TESTED |
| BUG-CMP-004 | 低 | Subsystem 兩種歷史值（8B04/8804） | 記錄不一致 | 雙側實測定案 0x8804 | — | RESOLVED |
| BUG-CMP-005 | 中 | OpenCL 支援未驗證（上游功能範圍包含） | 裝置初始化未完成 | 階段 B4 驗證 | — | NOT TESTED |

### 參考資料

| 名稱 | 連結 | 用途 |
|------|------|------|
| OpenCorePkg（1.0.8） | https://github.com/acidanthera/OpenCorePkg | ocvalidate／官方二進位檔 |
| OpenCore Configuration.pdf | https://github.com/acidanthera/OpenCorePkg/blob/master/Docs/Configuration.pdf | 設定項語義 |
| Dortania Install Guide／Coffee Lake | https://github.com/dortania/OpenCore-Install-Guide | 平台基線方法論 |
| NullMoth NVIDIA macOS Driver（2.6.5） | https://github.com/nullmoth/nvidia-macos-driver | 驅動研究對象（未整合其程式碼） |
| NullMoth CARD-SUPPORT／HOW-IT-WORKS／CHANGELOG | 見倉庫 docs/ | 驗證矩陣／架構／Turing 案例 |
| NVIDIA Open GPU Kernel Modules | https://github.com/NVIDIA/open-gpu-kernel-modules | Turing GSP 支援 |
| NVIDIA supportedchips（570.153.02） | https://us.download.nvidia.com/XFree86/Linux-x86_64/570.153.02/README/supportedchips.html | 官方表含 CMP 40HX |
| 1401 專案 | https://github.com/nullmoth/1401 | 安裝器形態 |
| pci.ids | https://pci-ids.ucw.cz/ | 10DE:1F0B = TU106 [CMP 40HX] |

第三方 kext 上游與授權：見 [NOTICE](NOTICE)。

### 深度研究文件

Docs/research/01 Windows 硬體取證 · 02 NullMoth 原始碼稽核 · 03 CMP 40HX 適配分析 · 04 Metal 實施計畫 · 09 EFI 來源溯源 · 10 Picker 稽核；Docs/BUG-DETECTION-MATRIX.md · BUG-FIX-LOG.md · INSTALL-LOG.md

### 授權條款

專案檔案：MIT（[LICENSE](LICENSE)）。隨包分發的 kext 二進位檔歸其上游所有，各自授權見 NOTICE。**禁止**：刪除授權與來源聲明後再分發。

### 免責聲明

本專案僅供學習研究。Hackintosh 依 Apple EULA 屬灰色地帶，使用風險自負；作者不對任何硬體損壞、資料遺失或違反 EULA 的後果負責。本專案與 Apple、NVIDIA、ASUS 無任何關聯。
