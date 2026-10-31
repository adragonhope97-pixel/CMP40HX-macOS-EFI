# EFI-PUBLIC-CONTENT-AUDIT — 公开 EFI 内容审计(v1.0)

## 保留(公开 ZIP 内容)

| 文件/目录 | 处理 | 原因 |
|-----------|------|------|
| OC/config.plist | **修改**:SMBIOS 身份清空;移除核显属性条目;新增版本注释头 | 隐私剥离;ocvalidate 1.0.8 复检零错误 |
| OC/ACPI/*.aml(6) | 原样保留 | 平台必需 SSDT;二进制扫描无隐私内容 |
| OC/Kexts/*(11) | 原样保留 | 启动必需;上游开源;NOTICE 列明来源与许可 |
| NOTICE/LICENSE/README/HARDWARE/Docs | 新增 | 审计声明与使用说明 |

## 删除/排除(不在公开 ZIP)

| 项 | 原因 |
|----|------|
| PlatformInfo 身份字段值 | 隐私红线(字段保留、值清空) |
| DeviceProperties 中核显条目 | 未授权公开的核显专用配置 |
| OpenCore.efi / BOOTX64.efi / OpenRuntime.efi / ResetNvramEntry.efi | 定制构建,版本不可证 → 使用者从官方 Release 获取 |
| HfsPlus.efi / apfs_aligned.efi | 第三方来源不可追溯 → 官方渠道获取(OcBinaryData / OCLP) |
| Resources/ | 非必需,减小攻击面 |
| Tools/ | 空目录 |

## 启动功能风险评估(如实)

- 剥离后 config 仍是合法可加载配置(ocvalidate 零错误),但**直接启动需要**:①使用者自己的 SMBIOS;②官方 OC 二进制;③核显用户自行补 framebuffer 属性。
- 因此本公开版定位为"**平台定制模板**"——这与"伪造看似通用实则不可用的 EFI"相反:所有缺口都明示并给出官方补齐路径。

## 无法安全公开的文件

- 含真实 SMBIOS 的原始 config(私有留档,永不公开)。
- 含本机 ioreg/系统日志的取证文件(私有留档)。
- 定制 OpenCore 二进制(私有留档;公开版以官方二进制替代)。
