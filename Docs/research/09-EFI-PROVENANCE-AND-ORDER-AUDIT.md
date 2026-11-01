# 09-EFI-PROVENANCE-AND-ORDER-AUDIT(v1.0,2026-11-01)

> 性质:只读溯源审计。方法:官方 Release/仓库下载 → SHA-256 对账 + Mach-O 解析 + 上游源码引用。未修改任何文件。

## 1. OpenCore 版本溯源(AUD-03)

| 项 | 结果 |
|----|------|
| 当前二进制 | OpenCore.efi 872,448 字节,SHA-256 `61ed3a88de58858c…`;BOOTx64.efi `c4c8e264…`;OpenRuntime.efi `12b9c304…`;ResetNvramEntry.efi `5217eff3…` |
| 对账范围 | 官方 1.0.4 / 1.0.5 / 1.0.6 / 1.0.7 / 1.0.8 **RELEASE** 与 1.0.8 **DEBUG** 全部 DIFF |
| 1401 流程证据 | 1401 仓库测试(test_opencore_components.py)表明**现行 1401 流程下载官方 OpenCore-1.0.8-RELEASE.zip 并逐组件校验**(BOOTx64/OpenCore/OpenRuntime);test_binary_mismatch_is_detected 证明新版流程会检测二进制替换 |
| 矛盾点 | 当前 G 盘二进制与官方 1.0.8 不一致,却声称出自 1401 流程 ⇒ 二进制出自**更早版本的 1401 流程**(其构建/补丁方式无公开记录),或含未知修改 |
| 结论 | **UNKNOWN —— 无法验证的二进制修改:存在可能性,无法排除**。缓解:现行 1401 已切换"官方 1.0.8 + 组件校验"模式,建议在下一轮 EFI 变更时用现行流程重建以恢复可验证性(需批准) |

## 2. Kext / Driver 来源清单(逐项对账)

| 组件 | 版本 | G 盘二进制 SHA-256(前16) | 上游 | 对账结果 | 定级 |
|------|------|---------------------------|------|----------|------|
| OpenCore.efi / BOOTx64.efi | 定制 | 61ed3a88… / c4c8e264… | OpenCorePkg | 全版本 DIFF | **UNKNOWN** |
| OpenRuntime.efi | 定制 | 12b9c304… | OpenCorePkg | DIFF | **UNKNOWN** |
| ResetNvramEntry.efi | 定制 | 5217eff3… | OpenCorePkg | DIFF | **UNKNOWN** |
| apfs_aligned.efi | — | 1663fa54… | OCLP 分发(推测) | 未对账(分发渠道确认成本高) | **UNKNOWN** |
| HfsPlus.efi | — | a55b5fff… | **acidanthera/OcBinaryData** | **MATCH** ✅ | 官方原版 |
| Lilu.kext | 1.7.3 | 6bc64e6d… | acidanthera/Lilu | **超出官方最新(1.7.2)** | 1401 分发,未对账 |
| WhateverGreen.kext | 1.7.2 | 059967ba… | acidanthera/WhateverGreen | **超出官方最新(1.7.1)** | 1401 分发,未对账 |
| VirtualSMC.kext | 1.3.9 | 33223469… | acidanthera/VirtualSMC | **超出官方最新(1.3.8)** | 1401 分发,未对账 |
| SMCProcessor / SMCSuperIO | 1.3.9 | — | 同 VirtualSMC 包 | 同上 | 同上 |
| RestrictEvents.kext | 1.1.7 | b54d0322… | acidanthera/RestrictEvents | **超出官方最新(1.1.6)** | 1401 分发,未对账 |
| USBToolBox.kext | (无版本号) | f6095d3b… | USBToolBox/kext(MIT) | 未对账(需上游 release 比对) | UNKNOWN-轻 |
| UTBDefault.kext | 1.0 | e831e8bc… | USBToolBox tool 生成 | **设计使然不可对账**(按机器生成) | 正常 |
| IntelMausiEthernet.kext | 3.0.3 | d28f30b4… | Mieze/IntelMausiEthernet | **超出官方最新 release(3.0.1)** | 1401 分发,未对账 |
| CtlnaAHCIPort.kext | 341.0.2 | 36dd57a2… | **HeaDragon/CtlnaAHCIPort(kext release)** | **MATCH** ✅ | 官方原版 |
| XHCI-unsupported.kext | 0.9.2 | 00fe5c09… | RehabMan 分发(非 GitHub release) | 未对账 | UNKNOWN-轻 |
| AMFIPass.kext | 1.4.1 | (本次部署,源=官方 zip) | kaoskinkae/AMFIPass v1.4.1 | **MATCH** ✅(zip 级 07b26614…) | 官方原版 |

**模式总结**:acidanthera 系四个核心 kext 与 IntelMausi 全部**领先官方最新 Release 一个版本** ⇒ 1401 工具链有自己的 kext 分发渠道(CI/nightly 或自有构建),面向 Tahoe/无头 GPU 调优。CtlnaAHCIPort/HfsPlus/AMFIPass 三个可对账项全部 MATCH,说明分发并非随意替换。**风险定性:供应链可信度依赖对 1401 工具链的信任;无法逐字节验证属已知限制。**

## 3. SHA-256 校验表

- 全量清单:`SHA256SUMS.txt`(本项目根,64+ 条)
- 上游对账源:`source-audit/SHA256SUMS-upstream.txt`(NullMoth 官方)、各 release zip 原件留存于 source-audit/kext-upstream/

## 4. Lilu 加载顺序分析(任务 3)

当前 Kernel→Add 顺序(实测读取):

```
1 CtlnaAHCIPort   2 IntelMausiEthernet   3 Lilu   4 AMFIPass   5 RestrictEvents
6 VirtualSMC   7 SMCProcessor   8 SMCSuperIO   9 USBToolBox   10 UTBDefault
11 WhateverGreen   12 XHCI-unsupported
```

分析:

1. OpenCore 按 Add 顺序注入;**Lilu 插件(WEG/RestrictEvents/VirtualSMC 系/AMFIPass)全部位于 Lilu 之后** → 无依赖违反 ✅
2. Lilu 之前的两个(CtlnaAHCIPort/IntelMausiEthernet)为**非 Lilu 插件**,顺序无关 ✅
3. ocvalidate 1.0.8 零错误(该工具会校验注入合法性)✅
4. Dortania 惯例"Lilu 第一"属**风格性/稳健性建议**,非 OpenCore 硬性依赖要求

**结论:当前顺序不存在真实错误或启动/匹配风险;BUG-EFI-004 定级维持 P3(风格性优化),仅在下次其他 EFI 变更时顺带处理,不单独重启。**

## 5. 发现的问题(含证据)

| ID | 级别 | 内容 | 证据 |
|----|------|------|------|
| PROV-001 | P2(供应链) | OC 四件套无法对账到任何官方发布物;是否存在修改 UNKNOWN | §1 对账表 |
| PROV-002 | P3(供应链) | 四个 acidanthera kext + IntelMausi 版本领先官方 Release,来源=1401 分发渠道,无法逐字节对账 | §2 表 + releases API 查询 |
| PROV-003 | INFO | HfsPlus/CtlnaAHCIPort/AMFIPass 三个可对账项全部 MATCH | §2 表 |
| PROV-004 | INFO | UTBDefault 为按机器生成,不可对账属设计使然 | USBToolBox 工具语义 |
| PROV-005 | INFO | apfs_aligned.efi/XHCI-unsupported 分发渠道特殊,对账成本高于价值 | §2 表 |

## 6. 可选修复方案(均未执行,待批准)

| 方案 | 内容 | 风险 | 回滚 | 重启 |
|------|------|------|------|------|
| A | 用**现行 1401 流程**重建 EFI(其已切换官方 1.0.8 + 组件校验)→ 恢复 OC 可验证性 | 中(重建引入新变量,需回归) | 三副本备份体系 | 是 |
| B | 仅替换 OC 四件套为官方 1.0.8 RELEASE 二进制 | 中(RELEASE 无文件日志,与 Target=67 组合行为变化;且定制构建可能含平台必要补丁) | 备份还原 | 是 |
| C | 维持现状,接受"1401 供应链信任" | 无(零改动) | — | 否 |
| D | 逐个对账剩余 kext(USBToolBox/XHCI/apfs_aligned) | 低 | — | 否(纯研究) |

**建议:C(维持)+ D(补充对账)并行;A/B 等 L4 结果出来后一并决策。**

## 7. Lilu 顺序可选修复

- 方案:将 Lilu.kext 移至 Add 首位(纯顺序调整)。
- 风险:极低;回滚:备份还原;需重启。
- 建议:与下次 EFI 变更同批执行,不单独重启。
