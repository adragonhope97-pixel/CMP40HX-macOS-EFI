# REGRESSION-TEST-REPORT(v1.1)

| 回归项 | 修复前 | 修复后 | 判定 |
|--------|--------|--------|------|
| efi-audit 对 G 盘 | FAIL=0(但 macOS 不可运行) | FAIL=0(修复后 Windows 复跑) | ✅ 无回归 |
| selftest 26 项 | 26/26 | 26/26 | ✅ 无回归 |
| 公开 ZIP 发布链 | SHA c6d1db29(旧)| 218dc2ba→30da2ef4(HARDWARE 更新后重建,回下载比对 PASS) | ✅ |
| 隐私扫描 | 零命中 | 零命中(8B04/8804 处理后复核) | ✅ |
| DGChat 仓库 | 未触碰 | 未触碰 | ✅ |
