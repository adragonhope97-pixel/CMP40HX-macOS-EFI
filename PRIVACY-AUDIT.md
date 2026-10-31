# PRIVACY-AUDIT — 隐私审计(v1.0)

> 审计范围:本仓库全部公开文件 + 最终 ZIP 解压内容。审计方式:字段级核对 + 全树正则扫描(大小写不敏感)+ 二进制 ASCII 扫描。

## 检查项与结果

| 检查项 | 方法 | 结果 |
|--------|------|------|
| SMBIOS 身份字段 | config 解析:SystemSerialNumber/MLB/SystemUUID/ROM | 全部为空 ✅ |
| MAC 地址 | config ROM 字段 + 全树正则 | 空/零命中 ✅ |
| 用户名/昵称/邮箱 | 全树正则(作者历史用户名与邮箱模式) | 零命中 ✅ |
| 本地路径/盘符 | 全树正则(C:\Users、/Users/、盘符) | 零命中 ✅ |
| Windows/macOS 用户目录 | 同上 | 零命中 ✅ |
| 未验证 Subsystem 候选值 | 全树正则(候选值字面量) | 零命中 ✅(文档仅述"待复核",不含字面值) |
| 网络信息(SSID/IP) | 全树正则 | 零命中 ✅ |
| 其他 PCI 设备详细清单 | 内容审查:HARDWARE/README 仅列授权硬件 | ✅ |
| P630 专用配置 | config 解析:iGPU DeviceProperties 条目 | 已移除 ✅ |
| ACPI AML 二进制扫描 | ASCII 模式扫描 6 个 .aml | 零命中 ✅ |
| Kext 二进制扫描 | 11 个 kext 可执行文件模式扫描 | 仅上游自带字符串(如 IOPlatformSerialNumber 符号名),无本机数据 ✅ |
| 文件元数据 | 公开文件为本机生成,无作者字段 | ✅ |
| ZIP 元数据 | zip 由脚本生成,仅相对路径条目,无绝对路径/用户名 | ✅(见 Checksums) |
| Git 历史 | 目标仓库历史扫描:发现仓库属主自己的提交署名(其本人资产,不属本项目文件);本项目新增文件不含任何身份信息 | 见发布报告 |
| 旧 Release | 目标仓库既有 Release 属 App 项目,本项目 Release 为新增条目,不触碰 | ✅ |

## 结论

公开集(README/HARDWARE/config/ACPI/Kexts/Docs/NOTICE/LICENSE)通过全部隐私检查。剩余风险:无(已知范围内)。
