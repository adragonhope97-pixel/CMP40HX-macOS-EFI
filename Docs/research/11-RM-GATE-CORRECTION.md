# 11. RM 门禁结论纠错：0xF 不是"不支持"，是"GPU 无响应"

> **状态**：L3（源码级证据，可复核）｜影响：修正此前文档中关于 RM 门禁的核心结论

## 1. 被纠正的结论

此前文档（含 README 七层状态表 3b、RESEARCH-LOG-NVRM-GATE）的表述是：

> `rm_is_supported_device -> 0xf` —— NVIDIA R615 RM 内部支持表不含 CMP SKU，因此拒绝 0x1F0B。

这个表述**有两处错误**。

## 2. 错误一：0xF 的含义读错了

日志原文：

```
rm_is_supported_device -> 0xf: RM will not drive device 0x1f0b - stopping, card untouched
```

`0xf` 被理解为"不支持"。对照 NVIDIA 自己的状态码定义
（`open-gpu-kernel-modules` → `src/common/sdk/nvidia/inc/nvstatuscodes.h`）：

| 状态码 | 常量 | 含义 |
|---|---|---|
| **0x0F** | **`NV_ERR_GPU_IS_LOST`** | **GPU lost from the bus（显卡从总线掉线）** |
| 0x56 | `NV_ERR_NOT_SUPPORTED` | Call not supported |
| 0x59 | `NV_ERR_OPERATING_SYSTEM` | Generic operating system error |

**0xF = GPU 无响应**，不是"设备不被支持"。

## 3. 错误二：`rm_is_supported_device` 根本不查 PCI ID 表

实现位置：`src/nvidia/arch/nvalloc/unix/src/osapi.c`（620.70.06）：

```c
pmc_boot_0  = NV_PRIV_REG_RD32(reg_mapping, NV_PMC_BOOT_0);
pmc_boot_42 = NV_PRIV_REG_RD32(reg_mapping, NV_PMC_BOOT_42);
...
if ((pmc_boot_0 == 0xFFFFFFFF) && (pmc_boot_42 == 0xFFFFFFFF)) {
    nv_printf(NV_DBG_ERRORS,
        "NVRM: ... has fallen off the bus and is not responding to commands.\n");
    rmStatus = NV_ERR_GPU_IS_LOST;      /* 0xF */
    goto threadfree;
}
```

函数内**没有任何设备 ID 表**。它做两件事：读 PMC 寄存器 → 用芯片架构查 HAL。

HAL 查找同样是**按硅片**而非按 PCI ID（`src/nvidia/src/kernel/core/hal_mgr.c`）：

```c
if ((decodePmcBoot42Architecture(pPmcBoot42) == chipID[publicHalID].arch) &&
    (DRF_VAL(_PMC,_BOOT_42,_IMPLEMENTATION,pPmcBoot42) == chipID[publicHalID].impl))
```

TU106 的期望值（`src/nvidia/generated/g_hal_archimpl.h`）：`ARCH = 0x16 (TU100)`，`IMPL = 6`。

**结论：CMP 40HX 是 TU106 硅片，只要 PMC 可读，就会匹配到 TU106 HAL。**
"安装器支持 ID 列表不含 1F0B"是脚本层的事实，与 RM 运行时判定无关。

## 4. 修正后的实际阻塞点

**显卡在 macOS 下对 BAR0 寄存器读不响应（返回 0xFFFFFFFF）。**

这与实测中另一条现象吻合：RM 访问 BAR0 后 GPU 停止响应。

## 5. 候选原因（按可测性排序）

| # | 假设 | 判定方法 |
|---|---|---|
| H1 | 内存解码未开启时读 BAR | 读 PCI command 寄存器 bit1 |
| H2 | 设备处于 D3hot | 读 PMCSR，必要时写回 D0 |
| H3 | Turing 上电后需约 10 秒稳定期 | 轮询 PMC 寄存器 12 秒 |
| H4 | BAR1（64MB，位于 4G 以上）分配异常 | 对比 BAR 值与固件分配 |
| H5 | ASPM / L1 子状态导致链路掉 | 检查链路电源管理状态 |
| H6 | 矿卡 BIOS 上电序列特殊 | 与 Windows 侧行为对比 |

## 6. 为什么这条纠错重要

- 原结论把问题定性为"上游政策限制，本项目无法解决"，实际上它是**硬件/时序层面的可测问题**。
- 上游整套栈是开源的（Metal 插件 → AIR→SPIR-V 翻译器 → NVK → kexts；RM 核心由
  `open-gpu-kernel-modules` 源码编译），**不存在需要绕过的 ID 白名单**。
- 下一步的正确方向是：判定 GPU 是否响应寄存器读，而不是尝试修改设备 ID。

## 7. 证据分级

| 证据 | 等级 |
|---|---|
| `nvstatuscodes.h` 中 0xF 的定义 | L3（源码） |
| `osapi.c` 门禁实现逻辑 | L3（源码） |
| `hal_mgr.c` 按架构匹配 HAL | L3（源码） |
| 实机日志中出现 `-> 0xf` | L4（日志） |
| "GPU 对 BAR0 读无响应" | L4 现象 + L3 代码路径推断，**待独立探针确认** |
