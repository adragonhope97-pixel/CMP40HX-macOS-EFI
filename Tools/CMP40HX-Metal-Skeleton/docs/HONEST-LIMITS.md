# 技术边界与风险（v0.1）

这份文档的目的是防止自我欺骗。任何一条被忽略，后面的工作都会建立在错误前提上。

## 1. 为什么骨架不能产生 Metal

macOS 的 GPU 加速链路是分层的，缺一层都不通：

```
应用 → Metal.framework → MTLDevice(userspace 驱动插件) → IOAccelerator2(内核服务) → GPU
                          ↑ MetalPluginName 属性指向的 bundle
```

- **内核层**：需要 IOAccelerator2 子类服务，且正确实现 Apple 定义的资源/队列/内存接口
- **用户态层**：需要 `MetalPluginName` 指向一个实现了 Metal 驱动 ABI 的 bundle
- **硬件层**：需要按 Turing 命令流格式提交工作（无公开文档，需逆向）

本骨架只做了「内核层的最外层」：设备枚举 + BAR 映射 + 属性发布。
**没有 IOAccelerator2、没有 Metal 插件、没有命令提交。** 因此不会有任何加速。

## 2. 与 NullMoth 的关系：不是补丁，是替代

| | NullMoth 2.6.5 | 本骨架 |
|---|---|---|
| 驱动核心 | NVIDIA 闭源 libnvrm | 自己写 |
| 设备门禁 | `rm_is_supported_device` 拒绝 0x1F0B | 无门禁（自己判断） |
| 能否驱动 CMP | 否（硬阻塞） | 可以枚举，但无加速 |
| 工作量 | 已存在 | 从零，长期 |

**共存问题（重要）**：本骨架 `IOProbeScore = 40000`，高于 NullMoth `NVRMFBClaim` 的 30000。
若两者同时加载，本骨架会抢占设备节点，NullMoth 将无法绑定。
- 实验期：这是有意为之（隔离测试）
- 正式期：必须重新设计探测策略，否则等于废掉 NullMoth 路线
- **切换前必须先卸载其中一个，不要靠分数硬碰**

## 3. 加载方式与签名

- **OpenCore 注入（推荐）**：OC 的 `Kernel > Add` 不校验签名，ad-hoc 签名或不签名均可加载。
  代价是每次改动要重启，且必须改 config.plist（改前备份）。
- **kmutil 直接加载**：macOS 11+ 对 kext 签名有要求，ad-hoc 签名在 SIP 未放宽时会失败。
  当前机器 `csr-active-config = 430a0000`，但 boot-args 中没有 AMFI 放宽参数，
  **直接加载大概率被拒**。不要为了它去改 boot-args——那会牵动已验证的显示链路。

## 4. 崩溃风险与责任边界

内核态代码出错 = 立即 panic，无日志可看（除非串口/另一台机器抓）。
本骨架的风险点按概率排序：

1. **BAR0 读取**（中）：只读首个 dword 通常安全，但若设备处于异常状态（此前 L4 日志出现过
   "fallen off bus"），读 BAR 可能触发总线错误 → panic
2. **ProbeScore 冲突**（中）：与 NullMoth 抢节点可能导致启动期不确定行为
3. **setMemoryEnable/setBusMasterEnable**（低）：已显式关闭 BusMaster，不允许 DMA
4. **C++ 运行时**（低）：kext 环境无完整 C++ 运行时，已禁用 RTTI/异常

**必须先确认**：动手前系统能正常进桌面（当前基线 `43182d0b` 已验证）。
**回滚**：删掉 OC `Kernel > Add` 里那一条 + Kexts 目录里的 kext，重启即可；不影响其他任何配置。

## 5. 工作量现实评估

| 阶段 | 内容 | 现实难度 |
|---|---|---|
| v0.1 骨架 | 枚举 + BAR 映射（本项目） | 低，几小时 |
| v0.2 受控寄存器访问 | 白名单读写 + 稳定性验证 | 中，数天 |
| v0.3 IOAccelerator2 | 子类化 + 资源管理 | 高，需私有头 + 大量试错 |
| v0.4 GSP 初始化 | 复用 open-gpu-kernel-modules 逻辑 | 极高，GSP 协议无完整文档 |
| v0.5 Metal 插件 | userspace 驱动 ABI | 极高，等于重写驱动栈 |

**结论**：v0.1→v0.2 是现实可做的；v0.3 以后是研究项目，不承诺任何时间表，
更不承诺"最终能 Metal"。如果目标是"尽快让 CMP 40HX 在 macOS 上跑 Metal 计算"，
唯一现实路径仍是上游 NullMoth 加入 CMP SKU（见 11 号报告的门禁分析）。

## 6. 合规

- 不使用、不反编译 NVIDIA 闭源代码（libnvrm）
- 不绕过任何 Apple 安全机制（不伪造签名、不注入未授权进程）
- 内核头文件来自 Xcode CLT 的 Kernel.framework，属正常开发用途
- 所有改动保留备份，可完整回滚
