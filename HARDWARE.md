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
| Wi-Fi | 无 WLAN 硬件(实测 Get-NetAdapter / netsh wlan 均无适配器) | Windows 实测 |

### CMP 40HX 补充说明

- Subsystem ID:**`0x8804`(Vendor 1043)** —— Windows PnP(`SUBSYS_88041043`)与 nvidia-smi(`Sub System Id 0x88041043`)双源实测一致;历史记录中的另一值经复核作废。
- PCIe 链路:实测 Link Up(速率/宽度以实机采集为准)。
- PCIe 链路:Gen1 ×4(设备原生上限,实测 Current=Max 有效带宽档);VBIOS 90.06.67.00.04;BAR1 64 MiB。
- 本卡无显示输出接口,定位为计算设备;显示由平台核显负责。

### 隐私边界

以下信息**不会**出现在本仓库:序列号、MAC 地址、网络信息、其他 PCI 设备的详细清单、核显专用配置细节。

---

## English

| Category | Model | Evidence |
|----------|-------|----------|
| Motherboard | ASUS ROG STRIX Z370-F GAMING | Author statement + verified EFI environment on the target machine |
| CPU | Intel Xeon E-2124G (Coffee Lake-S, 4 cores) | Author statement + verified EFI environment |
| NVIDIA GPU | NVIDIA CMP 40HX — Vendor `0x10DE` / Device `0x1F0B` / Revision `0x00A1` / **Subsystem `1043:8804`** | macOS System Information → PCI + Windows PnP + nvidia-smi (triple-source consistent) |
| Memory | 2 × 8GB DDR4-2666, PartNumber `HKED4081CAA1D0HA1` (brand field is an undecoded raw code `0B2C`; published by PartNumber) | Windows CIM (Win32_PhysicalMemory) |
| Wi-Fi | No WLAN hardware present (Get-NetAdapter / netsh wlan both return none) | Windows measurement |

### CMP 40HX Notes

- Subsystem ID: **`0x8804` (Vendor 1043)** — confirmed by dual sources on the target machine (Windows PnP + nvidia-smi); the other historical value is invalidated.
- PCIe link: Gen1 ×4 is the device-native maximum (measured); VBIOS 90.06.67.00.04; BAR1 64 MiB.
- The card has no display outputs; it is a compute device.
- The card has no display outputs; it is a compute device. Display is handled by the platform iGPU.

### Privacy Boundary

The following never appear in this repository: serial numbers, MAC addresses, network details, detailed lists of other PCI devices, iGPU-specific configuration details.

---

## 繁體中文（臺灣）

| 類別 | 型號 | 證據來源 |
|------|------|----------|
| 主機板 | ASUS ROG STRIX Z370-F GAMING | 使用者聲明 + 目標機器 EFI 實測環境 |
| CPU | Intel Xeon E-2124G（Coffee Lake-S，4 核心） | 使用者聲明 + EFI 實測環境 |
| NVIDIA GPU | NVIDIA CMP 40HX — Vendor `0x10DE` / Device `0x1F0B` / Revision `0x00A1` / **Subsystem `1043:8804`** | macOS 系統資訊 → PCI + Windows PnP + nvidia-smi 三源一致 |
| 記憶體 | 2 × 8GB DDR4-2666，PartNumber `HKED4081CAA1D0HA1`（品牌欄位為未解碼原始碼 `0B2C`，故按 PartNumber 公布） | Windows CIM 實測（Win32_PhysicalMemory） |
| Wi-Fi | 無 WLAN 硬體（實測 Get-NetAdapter／netsh wlan 均無适配器） | Windows 實測 |

### CMP 40HX 補充說明

- Subsystem ID：**`0x8804`（Vendor 1043）** —— Windows PnP 與 nvidia-smi 雙源實測一致；歷史記錄中的另一值經複核作廢。
- PCIe 連結：Gen1 ×4 為裝置原生上限（實測）；VBIOS 90.06.67.00.04；BAR1 64 MiB。
- 本卡無顯示輸出介面，定位為運算裝置。
- 本卡無顯示輸出介面，定位為運算裝置；顯示由平台內顯負責。

### 隱私邊界

以下資訊**不會**出現在本倉庫：序號、MAC 位址、網路資訊、其他 PCI 裝置的詳細清單、內顯專用設定細節。
