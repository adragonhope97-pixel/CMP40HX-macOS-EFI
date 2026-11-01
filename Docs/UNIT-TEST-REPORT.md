# UNIT-TEST-REPORT(v1.1)

| 套件 | 范围 | 结果 |
|------|------|------|
| selftest.sh(26 项) | lib 匹配回归×5 / model 校验×4 / 多匹配失败关闭 / SP 小写 / 02 事务(成功·Import 失败·P630 破坏·备份唯一·临时目录清理)/ P630 缺失·错误值 / 语法×7 | **26/26 PASS** |
| 语义审计 efi-audit(修复后) | <系统 EFI 分区> 12 项 | **FAIL=0**(E04/E10/E11/E09b = INFO 已入册) |
| 脚本语法 | 全部 7 个 shell 脚本 bash -n | PASS |
| fixture 注入 | ZDChat/正德校园墙/nbGd94188 断言(推送前) | 零命中 PASS |

执行环境:Windows 10 x64 + Git Bash + Python 3.14。macOS 侧单元测试(PlistBuddy 真实路径)待 L4。
