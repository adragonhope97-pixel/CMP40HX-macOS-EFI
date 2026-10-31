# HARDWARE / 硬件平台 / 硬體平台

简体中文 | [English](#english) | [繁體中文（臺灣）](#繁體中文臺灣)

> 本页只列出作者明确授权公开的硬件型号。每一项均附证据来源。**未提供实测证据的项目标注为 BLOCKED,不填写推测值。**

---

## 简体中文

| 类别 | 型号 | 证据来源 |
|------|------|----------|
| 主板 | ASUS ROG STRIX Z370-F GAMING | 用户声明 + 目标机器 EFI 实测环境 |
| CPU | Intel Xeon E-2124G(Coffee Lake-S,4 核) | 用户声明 + EFI 实测环境 |
| NVIDIA GPU | NVIDIA CMP 40HX — Vendor `0x10DE` / Device `0x1F0B` / Revision `0x00A1`(均为目标机器系统报告实测) | macOS 系统报告(System Information → PCI)实测 |
| 内存 | **BLOCKED** — 未提供实测证据(品牌/型号待补) | 暂无 |
| Wi-Fi | **BLOCKED** — 未提供实测证据(品牌/芯片/型号待补) | 暂无 |

### CMP 40HX 补充说明

- Subsystem ID:存在两种互相不一致的历史记录值,**均未在目标机器复核**,本页不公布任何候选值。
- PCIe 链路:实测 Link Up(速率/宽度以实机采集为准)。
- 本卡无显示输出接口,定位为计算设备;显示由平台核显负责。

### 隐私边界

以下信息**不会**出现在本仓库:序列号、MAC 地址、网络信息、其他 PCI 设备的详细清单、核显专用配置细节。

---

## English

| Category | Model | Evidence |
|----------|-------|----------|
| Motherboard | ASUS ROG STRIX Z370-F GAMING | Author statement + verified EFI environment on the target machine |
| CPU | Intel Xeon E-2124G (Coffee Lake-S, 4 cores) | Author statement + verified EFI environment |
| NVIDIA GPU | NVIDIA CMP 40HX — Vendor `0x10DE` / Device `0x1F0B` / Revision `0x00A1` (all read from the target machine's system report) | macOS System Information → PCI (measured) |
| Memory | **BLOCKED** — no measurement evidence provided yet (brand/model pending) | — |
| Wi-Fi | **BLOCKED** — no measurement evidence provided yet (brand/chip/model pending) | — |

### CMP 40HX Notes

- Subsystem ID: two mutually inconsistent historical record values exist; **not yet re-verified on the target machine**, so no candidate value is published here.
- PCIe link: measured Link Up (speed/width per on-machine capture).
- The card has no display outputs; it is a compute device. Display is handled by the platform iGPU.

### Privacy Boundary

The following never appear in this repository: serial numbers, MAC addresses, network details, detailed lists of other PCI devices, iGPU-specific configuration details.

---

## 繁體中文（臺灣）

| 類別 | 型號 | 證據來源 |
|------|------|----------|
| 主機板 | ASUS ROG STRIX Z370-F GAMING | 使用者聲明 + 目標機器 EFI 實測環境 |
| CPU | Intel Xeon E-2124G（Coffee Lake-S，4 核心） | 使用者聲明 + EFI 實測環境 |
| NVIDIA GPU | NVIDIA CMP 40HX — Vendor `0x10DE` / Device `0x1F0B` / Revision `0x00A1`（皆為目標機器系統報告實測） | macOS 系統資訊 → PCI 實測 |
| 記憶體 | **BLOCKED** — 尚未提供實測證據（品牌／型號待補） | 暫無 |
| Wi-Fi | **BLOCKED** — 尚未提供實測證據（品牌／晶片／型號待補） | 暫無 |

### CMP 40HX 補充說明

- Subsystem ID：存在兩種互相不一致的歷史記錄值，**均未於目標機器複核**，本頁不公布任何候選值。
- PCIe 連結：實測 Link Up（速率／寬度以實機採集為準）。
- 本卡無顯示輸出介面，定位為運算裝置；顯示由平台內顯負責。

### 隱私邊界

以下資訊**不會**出現在本倉庫：序號、MAC 位址、網路資訊、其他 PCI 裝置的詳細清單、內顯專用設定細節。
