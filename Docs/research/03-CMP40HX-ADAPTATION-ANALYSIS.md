# 03-CMP40HX-ADAPTATION-ANALYSIS(v1.0,2026-11-01)

> 逐项回答任务书第五阶段的 12 个问题。每项标注:L1/L2/L3/L4 证据等级与 PASS/FAIL/BLOCKED/NOT TESTED。**所有 L4 均未执行**(本阶段仅 Windows 研究)。

## 1. Turing 架构定性(L3)

CMP 40HX = TU106(TU10x 家族)。NVIDIA 官方支持表列名该卡;同族 GSP 固件 `gsp_tu10x`;NVK Turing 目标 sm_75。**结论:架构层面在 NVIDIA 官方支持范围内。** [L3 ✅]

## 2. GPU 引擎与硬件能力(L3)

Turing TU106:Async Compute ×3、 dedicated RT/Tensor(适配能力以 NVK/驱动查询为准,本项目不预填能力表)。实测显存 8GB、BAR1 64MB、PCIe Gen1×4(见 01)。

## 3. GSP 固件覆盖(L3 + L4 待)

615.78.08 GSP 按 TU10x 家族覆盖;**NVIDIA 官方 supportedchips 含 1F0B** → 固件族覆盖该设备。实际加载成功与否 = L4。[理论 ✅ / 实测 ⏳]

## 4. NVIDIA 驱动是否接受该 Device ID(L1/L3)

接受。链条:IOKit 探针(源码)→ install.sh 回退门禁(源码)→ NVIDIA 官方表(HTML)。**无一步需要伪造身份。** [L1/L3 ✅]

## 5. 显存布局识别(L4 待)

8GB GDDR6 实测(nvidia-smi);RM 如何向 macOS 报告显存布局 = L4(依赖 GSP bring-up)。[⏳]

## 6. BAR1 / GPU VA 初始化(L3 → L4)

- 实测 **BAR1 = 64MB**(矿卡特征,小于消费卡 256MB)。
- 上游处理:2.6.3 修复小 BAR1 卡顿;无 64-bit 窗口时保持固件放置;fallback 自动 100s settle(`nvrm-autogo-settle-ms`)。
- GPU VA:RM+GSP 管理,64-bit VA 与 BAR1 解耦(NVK 用 VA 访问显存)。
- **风险:64MB < 已知修复场景的 256MB,初始化路径未见公开成功案例。** [BLOCKED → 阶段 4 实测]

## 7. CMP 特有设备属性(L1)

上游源码无任何 CMP 分支/特判(全库搜索无 CMP 相关逻辑);即"当作普通 TU106 处理"。无特有属性。[L1 ✅]

## 8. 是否依赖显示输出硬件(L1/L3)

初始化不依赖显示输出(PCI/BAR/GSP 与 head 无关);**但 NVMTLDriver 的 headless 语义需要"另一 GPU 拥有桌面"**——见 §9。[L1 ✅ + 前置条件]

## 9. 无头 GPU 能否完成初始化(L1 → L4)

代码级:存在显式无头路径(headlessCheck → 恢复 MetalPluginName,不给 WindowServer 设备)。**前置条件:Intel IOFramebuffer 存在**(当前 -igfxvesa 阻断)。NVRM boot-hold 在无头下是否按超时释放 = 未知。 [代码 ✅ / 实测 ⏳ / 前置依赖 🔒]

## 10. NVK 能否正确创建设备(L1 → L4)

NVK 设备创建依赖 RM/GSP 就绪后暴露的通道;Turing 支持明确(sm_75、异步 copy 引擎已适配)。对 1F0B 无公开案例。[代码 ✅ / 实测 ⏳]

## 11. Metal Plugin 能否枚举该设备(L1 → L4)

NVMTLDevice.m:无头形态"apps get the NVIDIA Metal device"——上游显式设计;前提同 §9。[代码 ✅ / 实测 ⏳]

## 12. Metal Feature Set 与真实能力(L4)

Feature Set 由 NVK 能力查询动态生成;上游"未知芯片名拒绝猜测 sm 目标"→ 不存在错误能力表风险,但真实能力面待 L4。[⏳]

## 13. 设备 ID 映射评估(任务书要求逐项说明)

**结论:不需要,也不应做。**

- 为什么不需要:匹配链四层无一层要求 1F0B 伪装(回退门禁已放行)。
- 若映射为 1F02(RTX 2070)会发生什么:驱动按 TU106 全功能初始化(芯片同族,大概率"能跑"),但 ①违反任务书红线;②GSP 表仍不含 1F0B,问题只是被转移;③能力判断基于错误的产品名,不改变硬件事实;④上游更新时补丁漂移。
- 验证映射有效的成本:等于直接实测真身(1F0B)的成本——**映射毫无收益**。

## 14. 汇总判定表

| 问题 | 判定 | 证据级 |
|------|------|--------|
| 驱动接受 1F0B? | 接受(回退门禁) | L1/L3 |
| 需要修改驱动源码? | 当前不需要(3 个预案挂起) | L1 |
| 需要新增匹配规则? | 不需要 | L1 |
| 需要适配 GSP? | 不需要(固件族覆盖);实机待证 | L1/L3 |
| GPU 初始化能完成? | 未知(BAR1 64MB + 无头 hold 两疑点) | BLOCKED |
| 能被 Metal 枚举? | 代码级支持,需 Intel FB 前置 + L4 | BLOCKED |
| 能跑 Metal Compute? | 前置满足后预期可行 | NOT TESTED |
| 能承担 Metal Rendering? | 同上(渲染=离屏;窗口合成归 Intel) | NOT TESTED |
| 能承担显示输出? | **不能**(无物理输出 + 上游拒绝在无头 GPU 上启动 WindowServer) | L1/L3 |
| 已通过 L4? | 仅:PCI 枚举、macOS 启动(P630 显示) | — |
| 无法确认的 | 上表全部 ⏳/BLOCKED 项 | — |

## 15. 前置依赖链(给后续阶段的硬结论)

```
CMP 40HX Metal 可见 ⇒ 需要 NVAccel headless 走"恢复 Metal 名单"分支
                    ⇒ 需要 Intel IOFramebuffer 存在
                    ⇒ 需要移除 -igfxvesa(BUG-P630-001)
                    ⇒ 需要先确认 Tahoe 26.7.2 的 AppleIntelCFLGraphicsFramebuffer 可加载
```

即:**"CMP 40HX 成为 Metal GPU" 与 "修复 P630 加速" 是同一条依赖链上的两环**,单独做 CMP 侧无法达成目标。该结论直接决定第四阶段(Metal 适配)的实施顺序。
