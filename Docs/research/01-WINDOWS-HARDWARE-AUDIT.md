# 01-WINDOWS-HARDWARE-AUDIT(v1.0,2026-11-01)

> 采集环境:目标机器 Windows(与 macOS 双系统的同一台物理机)。
> 方法:PowerShell PnP/CIM、`nvidia-smi -q`、`netsh`、`git credential` 无关项未触碰。
> 等级:**L3(外部硬件证据)**。无法从 OS 读取的字段标 UNKNOWN。

## 1. CMP 40HX PCI 身份(实测,三源一致)

| 字段 | 实测值 | 来源 |
|------|--------|------|
| Vendor / Device ID | `10DE:1F0B` | PnP InstanceId + nvidia-smi(Device Id 0x1F0B10DE) |
| Revision | `0x00A1`(REV_A1) | PnP InstanceId |
| **Subsystem Vendor / ID** | **`1043 / 0x8804`** | PnP `SUBSYS_88041043` + nvidia-smi `Sub System Id 0x88041043` 双源一致 |
| PCI 地址(Windows) | Domain 0 / Bus 0x02 / Device 0x00 / Func 0(0000:02:00.0) | nvidia-smi -q |
| Windows 命名 | "NVIDIA GeForce RTX 2060 SUPER" | 驱动 INF 通用命名,**不作为身份依据** |
| Status / Class | OK / Display | PnP |

**Subsystem ID 悬案结论:实测 = `0x8804`。历史值 0x8B04 作废。**(后续所有文档以 8804 为准;该值不参与 NullMoth 任何匹配层,见 02。)

## 2. PCIe 链路(实测,nvidia-smi -q)

| 项 | 值 |
|----|-----|
| Link Speed | Max: **Device=Gen1**,Host=Gen3;Current=Gen1(2.5 GT/s) |
| Link Width | Max: 16x;Current: **4x** |

**定性:Gen1 ×4 是本卡硬件本性**(与公开评测数据 CMP 40HX "PCIe 1.0 x4" 一致),不是故障、不是插槽问题。影响:主机↔GPU 数据搬运带宽约 1 GB/s 量级——对 GSP 初始化与中小规模计算无碍,对大吞吐计算任务构成带宽上限(记录为硬件特征,非 Bug)。

## 3. 显存与 BAR(实测)

| 项 | 值 | 备注 |
|----|-----|------|
| 显存容量 | 8192 MiB(8 GB GDDR6) | nvidia-smi |
| **BAR1** | **Total 64 MiB**(Used 2/Free 62) | ⚠️ **小 BAR1(64MB)**——NullMoth 2.6.3 已修复"小 BAR1 窗口卡拖动/拷贝卡顿"并含无 64-bit 窗口时的 BAR1 保持逻辑;64MB 比该修复提到的 256MB 更小,列为适配风险项(见 03) |
| BAR0/BAR2 精确映射 | UNKNOWN(需 PCI 配置空间 dump 工具) | 待 L3 补充 |
| Resizable BAR | 无迹象(-q 无 ReBAR 字段;UNKNOWN,需 BIOS 确认) | — |
| VBIOS | **90.06.67.00.04**(只读) | nvidia-smi |

## 4. 平台信息(实测)

| 项 | 值 | 备注 |
|----|-----|------|
| 主板 | ASUS ROG STRIX Z370-F GAMING | 用户声明 + EFI 实测环境 |
| BIOS | American Megatrends **"3004 (community-modified build)"**,2023-01-24 | **第三方修改版 BIOS**;Above 4G / CSM / ReBAR 状态 OS 不可读 → **UNKNOWN,进 BIOS 人工确认** |
| CPU | Intel Xeon E-2124G | — |
| P630(原生 ID) | `<Intel 原生 ID(不公开)>`,<核显 Subsystem(不公开)>,Rev 00 | Windows 实测(macOS 中 spoof 为 <Intel spoof 值(不公开)>) |
| P630 Windows 驱动 | 31.0.101.2145 | — |
| NVIDIA Windows 驱动 | 617.14(WMI 呈现 32.0.16.1714) | 仅 Windows 侧;与 macOS 栈无关 |
| 内存 | 2 × 8GB,PartNumber `HKED4081CAA1D0HA1`,DDR4-2667(Manufacturer 原始码 `0B2C` 未解码) | 序列号未采集(隐私) |
| 网卡 | Intel I219-V(Up)+ Hyper-V 虚拟网卡 | — |
| **WLAN** | **未检测到 WLAN 适配器**(Get-NetAdapter / netsh 均无) → 机器无 Wi-Fi 硬件 | 实测 |
| CSM / Above 4G Decoding | **UNKNOWN**(OS 不可读;BIOS 为改版) | 进 BIOS 人工确认 |

## 5. 当前 EFI(摘要,详见 FullEFI 工程)

- OpenCore:1401 定制构建(版本不可证);config = v0.4.2(含 CMP `model` 注入于 `PciRoot(0x0)/Pci(0x1,0x1)/Pci(0x0,0x0)`);P630 DeviceProperties 原样。
- kext 11 个(版本清单见 FullEFI/KEXT-INVENTORY);ACPI 6 SSDT。
- 完整结构与哈希:FullEFI/Evidence/SHA256SUMS.txt。

## 6. 遗留取证缺口(不影响本阶段结论)

1. BAR0/BAR2 精确基址与长度(需 RWEverything/pciutils 类工具,可后补)。
2. Above 4G / CSM / ReBAR(需进 BIOS 拍照确认)。
3. macOS 侧 IORegistry 复核(需目标机操作,属 L4)。
