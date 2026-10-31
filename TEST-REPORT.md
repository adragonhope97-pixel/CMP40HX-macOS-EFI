# TEST-REPORT — 测试报告(v1.0,分级如实)

## L1 静态检查(已执行)
- 公开版 config.plist:plistlib 解析 ✅;ocvalidate 1.0.8(官方工具)零错误 ✅
- 语义审计:公开 EFI 结构/ACPI 一致/kext 在盘/CMP 条目 ✅(详见 PRIVACY-AUDIT 与 EFI-PUBLIC-CONTENT-AUDIT)
- 隐私扫描:身份字段空 ✅;全树用户名/路径/未验证子系统扫描 ✅ 零命中

## L2 自动化测试(已执行,私有环境)
- 工具自测套件 26/26 PASS(含 PlistBuddy 中途失败、P630 破坏注入、备份唯一性、临时目录清理)
- 模型校验/路径匹配夹具(多节点拒绝、小写 ID、跨节点不误读)全过

## L3 外部硬件证据(已执行)
- Windows Location Path / ACPI 路径(候选路径级)
- NVIDIA 官方 supportedchips 表含 CMP 40HX(1F0B)

## L4 目标机实测(部分完成)
| 项 | 状态 |
|----|------|
| macOS 启动(P630 显示)| PASS(用户日常使用;v0.4.2 config 更新后待复测) |
| CMP 40HX PCI 枚举 | PASS(系统报告:10DE/1F0B/00A1,Link Up) |
| 名称显示(model 注入后) | 待复测(注入写入后未重启验证)|
| NVIDIA 驱动加载 | NOT TESTED |
| GSP / GPU 初始化 | NOT TESTED |
| Metal / Vulkan 计算 | NOT TESTED |
| 睡眠/唤醒/重启/关机回归 | NOT TESTED |
| 音频 / USB 定制 | NOT TESTED |

**声明:名称注入已配置但尚未完成重启后的实机确认;驱动层全部 NOT TESTED。**
