# 19 号报告：探针不加载的 10 方案裁决（10→5→2→1）

日期：2026-11-21
结论等级：L3（源码/二进制/日志证据）+ L4（实机两次失败）

## 0. 现象

| 证据 | 值 |
|---|---|
| 部署 | 成功，config 12→13 条，`plutil` 合法，备份在 U 盘 |
| 重启后 `ioreg -c CMP40HXAccelerator` | **空** |
| 内核日志 CMP40HX 相关 | **无** |
| NVRMFBClaim 计数 | 3（NullMoth 仍在） |

## 1. 十个候选方案

| # | 方案 | 依据 |
|---|---|---|
| S1 | 源码显式 `__attribute__((used, section("__DATA,__kmod_info")))` | Mach-O 段表实测缺该段 |
| S2 | 链接期 `-Wl,-sectcreate,__DATA,__kmod_info,<200B blob>` 强制注入 | 编译器不可控时的物理兜底 |
| S3 | **双 ESP 同步**（U 盘 + 内置 ESP 同时部署） | 内置 ESP 上有 OC 日志，U 盘无 |
| S4 | 提高 IOProbeScore / 卸载 NullMoth | NVRM=1000、NVRMFBClaim=30000 |
| S5 | 改 `IOPCIMatch` + 双 personality | 设备 compatible 含 pci10de,1f0b |
| S6 | `kmutil load` 直接加载（绕过 OC 注入） | 排除注入链路 |
| S7 | 装进 `/Library/Extensions` + AuxKC | 与 NullMoth 同路径 |
| S8 | 降 `OSBundleLibraries` 版本 / 去依赖 | KPI 21.0.0 |
| S9 | 改 `Arch=x86_64` 等条目字段 | OC 模板差异 |
| S10 | 改用 xcodebuild 工程生成 kext | 官方工具链 |

## 2. 第一轮：10 → 5

| 淘汰 | 理由（证据） |
|---|---|
| S8 | macOS 26 的 KPI 版本 ≥ 21；版本过高会**显式报错**而非静默跳过 |
| S9 | `Arch=Any` + `ExecutablePath` 与官方键集一致，`ocvalidate 1.0.8` 零错误 |
| S5 | 匹配失败只导致"已加载但无实例"，不会导致"完全未加载"；且 compatible 已含 `pci10de,1f0b` |
| S7 | 需放宽 SIP/AMFI 且要重建 AuxKC，与已安装的 NullMoth 冲突，风险高且不可快速回滚 |
| S10 | 只改构建方式，不解决段缺失；且需要完整 Xcode IDE |

**保留**：S1、S2、S3、S4、S6

## 3. 第二轮：5 → 2

| 淘汰 | 理由（证据） |
|---|---|
| S4 | ProbeScore 只影响 **attach 竞争**，不影响 **load**。且 40000 > NVRM(1000) > NVRMFBClaim(30000)，分数上我们赢。只有在"已加载却无实例"时才需要它 |
| S6 | `kmutil load` 在 SIP/AMFI 未放宽时会被拒（当前 boot-args 无 `amfi_get_out_of_my_way`），且每次重启失效 |

**保留**：S1+S2（让二进制合法）、S3（让改动真正生效）

## 4. 第三轮：2 → 1

两个候选不是竞争关系，而是**必须同时成立**的两半：

- S1+S2 解决"二进制能不能被内核接受"
- S3 解决"改动有没有进入实际引导的那份配置"

**最终方案（S1+S2+S3 合并）**：

1. 源码显式声明 `__kmod_info` 段（`used` 防优化）
2. 构建期 `otool` 断言该段存在；缺失则自动 `-sectcreate` 注入 200 字节 `kmod_info.bin`
3. 断言仍失败 → `exit 4` 中止部署（绝不再出现"以为成功其实没加载"）
4. 部署时**同时写 U 盘与内置 ESP**，两份 config + 两份 kext，SHA 双向核对
5. 引导后用三证验证：`kmutil showloaded`（是否加载）、`ioreg`（是否 attach）、内核日志（探针输出）
6. 兜底诊断：OC 文件日志（`Misc>Debug>Target=0x43` 已开）会记录 kext 加载失败原因

## 5. S3 的决定性证据

内置 ESP（KingFast 的 `disk4s1`）根目录有 3 份 OpenCore 日志：

```
opencore-2026-11-20-222218.txt   12:969 OCB: Should boot from 4. MacOS
opencore-2026-11-20-224800.txt   12:679 OCB: Should boot from 1. Windows
opencore-2026-11-20-225002.txt   12:870 OCB: Should boot from 1. Windows
```

**U 盘根目录：一份日志都没有。**

结论：11-20 那次成功进入 macOS 的引导，用的是**内置 ESP**，不是 U 盘。
而内置 ESP 的 config 至今只有 **12 条**（无 CMP 探针条目）——
所以 11-21 部署到 U 盘的那次修改，很可能根本没被加载。

（同时，第一次构建缺 `__kmod_info` 也是真实的第二个独立缺陷，两者叠加。）

## 6. 已实施

| 项 | 状态 |
|---|---|
| S1 源码显式段 | 已改（`src/CMP40HXAccelerator.cpp`） |
| S2 sectcreate 兜底 | 已加（`src/kmod_info.bin` 200B + `build.sh` fallback） |
| 构建期断言 | 已加（打印全部 segment/section，缺失即 exit 4） |
| S3 双 ESP 同步 | 已加进 `mac-99-do-everything.command`（自动找系统盘的 ESP，sudo 挂载，备份后同步） |
| 内置 ESP 备份 | `Integration/EFI-internal-ESP-backup-20261121-0930.tar.gz` |
