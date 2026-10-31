# CMP 40HX EFI — macOS / OpenCore 適配研究

简体中文 | [English](#english) | [繁體中文（臺灣）](#繁體中文臺灣)

---

## 简体中文

### 项目简介

本项目是一个面向 **NVIDIA CMP 40HX** 的 macOS / OpenCore EFI 适配与驱动研究项目，目标是探索 CMP 40HX 在 macOS 环境中的设备识别、驱动初始化和 GPU 计算能力适配。

### 项目目标

1. 让 macOS 原生枚举并识别 CMP 40HX（PCI 层）。
2. 研究 NullMoth NVIDIA macOS Driver 对 Turing / CMP 40HX 的适配路径。
3. 保持平台原有显示 GPU 正常工作，双 GPU 并存。
4. 公开一套经过隐私清理、可审查、可复现的 EFI 配置。

### 硬件平台

见 [HARDWARE.md](HARDWARE.md)。

### CMP 40HX 适配情况

| 层级 | 状态 |
|------|------|
| PCI 枚举（10DE:1F0B） | 已在目标机器实测成功 |
| 设备名称显示（系统信息 → PCI） | 已配置 model 注入，实机显示状态见测试报告 |
| NVIDIA 内核驱动（NVRM 等） | **未安装 / NOT TESTED**（上游研究完成，安装未获批准） |
| GSP 固件加载 / GPU 初始化 | NOT TESTED |
| Metal / Vulkan 计算 | NOT TESTED |
| OpenCL | 上游驱动栈不提供，不在目标内 |

### EFI 文件说明

- `EFI/OC/config.plist` — 隐私清理后的配置：已移除 SMBIOS 身份字段与 Intel 核显专用属性，保留 CMP 40HX 的 `model` 注入。
- `EFI/OC/ACPI/*.aml` — Coffee Lake 平台标准 SSDT。
- `EFI/OC/Kexts/*` — 第三方开源 kext（清单与上游链接见 [NOTICE](NOTICE)）。
- **不包含**任何 OpenCore / bootloader 二进制（来源要求见 NOTICE 与 Docs/）。

### 使用限制

本 EFI 是“平台定制模板”，不是通用 EFI：

1. 必须自行生成 SMBIOS（GenSMBIOS）并填入 PlatformInfo。
2. 必须从 OpenCore 官方 Release 获取引导二进制并放入对应位置（清单见 Docs/）。
3. Intel 核显属性已剥离；核显用户需按 Dortania 指南自行补齐。
4. `model` 注入路径 `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` 来自作者机器实测，其他机器必须用 Docs 提供的方法重新确认。

### 兼容性说明

基于 Coffee Lake-S 平台 + Xeon 处理器构建。其他平台请对照 Docs/ 逐项评估，不可直接照搬。

### 已知问题

- 板载音频 / USB 定制映射 / 核显图形加速等平台问题仍在处理中，详见 BUG-REPORT.md。
- CMP 40HX 驱动层（NullMoth）全部状态为 NOT TESTED。

### 测试等级

L1 静态检查 / L2 自动化测试 / L3 外部硬件证据 / L4 目标机实测。本项目所有已宣称的结论只到 L1–L3；L4 项均标注 NOT TESTED。详见 TEST-REPORT.md。

### 项目开发过程

见 DEVELOPMENT-LOG.md（完整阶段记录）。

### 开发规则

见 DEVELOPMENT-RULES.md（证据规则、隐私规则、禁止事项）。

### 技术决策

见 TECHNICAL-DECISIONS.md（匹配链 / GSP 门禁 / 无头路径 / 隐私剥离依据）。

### Bug 记录

见 BUG-REPORT.md。

### 参考资料

见 [REFERENCES.md](REFERENCES.md)。第三方组件许可见 [NOTICE](NOTICE)。

### 许可证

项目文件：MIT（见 [LICENSE](LICENSE)）；第三方 kext 各自许可，见 NOTICE。

### 免责声明

本项目仅供学习研究。Hackintosh 依 Apple EULA 属灰色领域，使用风险自负；作者不对任何硬件损坏、数据丢失或违反 EULA 的后果负责。本项目与 Apple、NVIDIA、ASUS 无任何关联。

---

## English

### Introduction

This project explores macOS / OpenCore EFI adaptation and driver compatibility for the NVIDIA CMP 40HX, focusing on device identification, driver initialization, and GPU computing capabilities.

### Goals

1. Native PCI enumeration and identification of the CMP 40HX on macOS.
2. Research the NullMoth NVIDIA macOS Driver path for Turing / CMP 40HX.
3. Keep the platform's existing display GPU working — dual-GPU coexistence.
4. Publish a privacy-cleaned, reviewable, reproducible EFI configuration.

### Hardware Platform

See [HARDWARE.md](HARDWARE.md).

### CMP 40HX Adaptation Status

| Layer | Status |
|-------|--------|
| PCI enumeration (10DE:1F0B) | Verified on the target machine |
| Device name (System Information → PCI) | `model` injection configured; see TEST-REPORT |
| NVIDIA kernel driver (NVRM etc.) | **Not installed / NOT TESTED** (upstream research done; installation not approved) |
| GSP firmware load / GPU init | NOT TESTED |
| Metal / Vulkan compute | NOT TESTED |
| OpenCL | Not provided by the upstream stack; out of scope |

### EFI Contents

- `EFI/OC/config.plist` — privacy-cleaned: SMBIOS identity fields and the Intel iGPU property block removed; the CMP 40HX `model` injection kept.
- `EFI/OC/ACPI/*.aml` — standard Coffee Lake platform SSDTs.
- `EFI/OC/Kexts/*` — third-party open-source kexts (list and upstream links in [NOTICE](NOTICE)).
- **No** OpenCore / bootloader binaries are included (provenance requirements in NOTICE and Docs/).

### Usage Restrictions

This EFI is a “platform-specific template”, not a universal one:

1. Generate your own SMBIOS (GenSMBIOS) and fill PlatformInfo.
2. Take bootloader binaries from official OpenCore releases (mapping in Docs/).
3. Intel iGPU properties were stripped; iGPU users must add their own per Dortania.
4. The `model` injection path `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` was verified on the author's machine — re-verify on yours using Docs/.

### Compatibility

Built for a Coffee Lake-S platform with a Xeon CPU. Other platforms must be evaluated item by item against Docs/ — do not copy blindly.

### Known Issues

- Onboard audio / custom USB mapping / iGPU graphics acceleration are still being worked on — see BUG-REPORT.md.
- All CMP 40HX driver-layer (NullMoth) statuses are NOT TESTED.

### Testing Levels

L1 static / L2 automated / L3 external hardware evidence / L4 target-machine testing. Claims in this repo only reach L1–L3; L4 items are marked NOT TESTED. See TEST-REPORT.md.

### Development Process

See DEVELOPMENT-LOG.md.

### Development Rules

See DEVELOPMENT-RULES.md.

### Technical Decisions

See TECHNICAL-DECISIONS.md.

### Bug Records

See BUG-REPORT.md.

### References

See [REFERENCES.md](REFERENCES.md); third-party licenses in [NOTICE](NOTICE).

### License

Project files: MIT ([LICENSE](LICENSE)); bundled kexts under their own licenses, see NOTICE.

### Disclaimer

For study and research only. Hackintoshing sits in a gray area of Apple's EULA; use at your own risk. The authors are not responsible for hardware damage, data loss, or EULA violations. Not affiliated with Apple, NVIDIA, or ASUS.

---

## 繁體中文（臺灣）

### 專案簡介

本專案是一個面向 **NVIDIA CMP 40HX** 的 macOS／OpenCore EFI 適配與驅動研究專案，旨在探索 CMP 40HX 在 macOS 環境中的裝置識別、驅動初始化與 GPU 運算能力適配。

### 專案目標

1. 讓 macOS 原生列舉並識別 CMP 40HX（PCI 層）。
2. 研究 NullMoth NVIDIA macOS Driver 對 Turing／CMP 40HX 的適配路徑。
3. 保持平台原有顯示 GPU 正常運作，雙 GPU 並存。
4. 公開一套經過隱私清理、可審查、可重現的 EFI 設定。

### 硬體平台

見 [HARDWARE.md](HARDWARE.md)。

### CMP 40HX 適配情況

| 層級 | 狀態 |
|------|------|
| PCI 列舉（10DE:1F0B） | 已於目標機器實測成功 |
| 裝置名稱顯示（系統資訊 → PCI） | 已設定 model 注入，實機顯示狀態見測試報告 |
| NVIDIA 核心驅動（NVRM 等） | **未安裝 / NOT TESTED**（上游研究完成，安裝未獲批准） |
| GSP 韌體載入 / GPU 初始化 | NOT TESTED |
| Metal / Vulkan 運算 | NOT TESTED |
| OpenCL | 上游驅動堆疊不提供，不在目標內 |

### EFI 檔案說明

- `EFI/OC/config.plist` — 隱私清理後的設定：已移除 SMBIOS 身分欄位與 Intel 內顯專用屬性，保留 CMP 40HX 的 `model` 注入。
- `EFI/OC/ACPI/*.aml` — Coffee Lake 平台標準 SSDT。
- `EFI/OC/Kexts/*` — 第三方開源 kext（清單與上游連結見 [NOTICE](NOTICE)）。
- **不包含**任何 OpenCore／bootloader 二進位檔（來源要求見 NOTICE 與 Docs）。

### 使用限制

本 EFI 是「平台定制範本」，不是通用 EFI：

1. 必須自行產生 SMBIOS（GenSMBIOS）並填入 PlatformInfo。
2. 必須從 OpenCore 官方 Release 取得引導二進位檔並放入對應位置（清單見 Docs）。
3. Intel 內顯屬性已移除；內顯使用者需依 Dortania 指南自行補齊。
4. `model` 注入路徑 `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)` 來自作者機器實測，其他機器必須用 Docs 提供的方法重新確認。

### 相容性說明

基於 Coffee Lake-S 平台 + Xeon 處理器建置。其他平台請對照 Docs 逐項評估，不可直接照搬。

### 已知問題

- 板載音效／USB 定制映射／內顯圖形加速等平台問題仍在處理中，詳見 BUG-REPORT.md。
- CMP 40HX 驅動層（NullMoth）全部狀態為 NOT TESTED。

### 測試等級

L1 靜態檢查／L2 自動化測試／L3 外部硬體證據／L4 目標機實測。本專案所有已宣稱的結論只到 L1–L3；L4 項均標註 NOT TESTED。詳見 TEST-REPORT.md。

### 專案開發過程

見 DEVELOPMENT-LOG.md（完整階段記錄）。

### 開發規則

見 DEVELOPMENT-RULES.md（證據規則、隱私規則、禁止事項）。

### 技術決策

見 TECHNICAL-DECISIONS.md（匹配鏈／GSP 門檻／無頭路徑／隱私移除依據）。

### Bug 記錄

見 BUG-REPORT.md。

### 參考資料

見 [REFERENCES.md](REFERENCES.md)。第三方元件授權見 [NOTICE](NOTICE)。

### 授權條款

專案檔案：MIT（見 [LICENSE](LICENSE)）；第三方 kext 各自授權，見 NOTICE。

### 免責聲明

本專案僅供學習研究。Hackintosh 依 Apple EULA 屬灰色地帶，使用風險自負；作者不對任何硬體損壞、資料遺失或違反 EULA 的後果負責。本專案與 Apple、NVIDIA、ASUS 無任何關聯。
