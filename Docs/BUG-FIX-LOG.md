# BUG-FIX-LOG(v1.1,本轮全部修复记录)

## FIX-1 / BUG-TOOL-001
- 文件:`CMP40HX-FullEFI/Tests/efi-audit.sh`(同步副本于 Metal-Adaptation/tests/)
- 函数:`runpy()`
- 修改前:`runpy() { python - "$@"; }`
- 修改后:`command -v python3` 优先,回退 `python`
- 行为变化:macOS(无 python 别名)上审计可执行
- 测试:bash -n ✅;Windows 回归(G 盘)FAIL=0 ✅;macOS 侧实跑待 L4
- 回滚:PATCH-DIFFS/BUG-TOOL-001-*.diff 反向应用

## FIX-2 / BUG-TOOL-002
- 文件:`research/collect-intel-fb-evidence.sh`
- 位置:检查项 03
- 修改:增 KernelCollections `grep -ac` 检查 + 密封卷口径说明;SLE 检查加 `2>/dev/null`
- 测试:bash -n ✅;实际输出待目标机(L4)
- 回滚:BUG-TOOL-002-*.diff 反向应用

## FIX-3 / BUG-TOOL-003
- 文件:`02-apply-name-injection.sh`
- 位置:提交后复核段
- 修改:`plutil || true` → 显式 PASS/警告输出
- 测试:bash -n ✅
- 回滚:BUG-TOOL-003-*.diff 反向应用

## FIX-4 / BUG-DOC-001 + BUG-CMP-004(证据更新)
- 文件:公开仓库 HARDWARE.md(三语)
- 内容:Subsystem 定案 0x8804(双源);内存 2×8GB HKED4081CAA1D0HA1(实测);Wi-Fi 无硬件(实测);CMP 补 VBIOS/BAR1/PCIe 事实
- 验证:推送成功;Release 附件重建;回下载哈希比对 PASS;内容断言(含 0x8804/PartNumber、无 8B04)PASS
- 回滚:git revert 单提交

## FIX-5 / 既有 BUG-EFI-007(公开范围)
- 状态维持:公开版无二进制(2026-10-31 已修);私有范围仍 OPEN

## FIX-6 / BUG-P630-001(2026-11-01 执行,用户直接下令)
- 文件:`<系统 EFI 分区>/EFI/OC/config.plist`(在用 EFI,手术式文本替换,其余字节不变)
- 修改前:`-v debug=0x100 keepsyms=1 igfxonln=1 -igfxvesa revpatch=sbvmm`
- 修改后:`-v debug=0x100 keepsyms=1 igfxonln=1 revpatch=sbvmm`
- diff:仅 1 行(628 行);P630 四键/CMP model/csr 核对不动 ✅;ocvalidate 1.0.8 零错误 ✅
- 备份:`Integration/G-EFI-config-backup-20261101-015105-pre-igfxvesa-removal.plist`(SHA-256 b84f579b…e8ff)
- 备注:06 计划的 Stage 0 基线采集被用户指令跳过("直接干修复");"修复前无 Intel IOFramebuffer"的 IORegistry 直接证据因此缺采集,以现象证据(14MB/20FPS)替代入档
- 测试:待用户重启 → 10-p630-diagnose.sh(L4)
- 回滚:备份覆盖回 <系统 EFI 分区>/EFI/OC/config.plist(Windows 侧即可完成,无需 macOS)
- 公开仓库:暂不同步(等实机结果;结果良好后再更新公开 README/ZIP)

## DEPLOY-1 / Exp-N1 部署(2026-11-01,用户指令"直接部署")
- 部署对象:`<系统 EFI 分区>/EFI`(在用 EFI)
- 部署前备份:`Integration/EFI-before-ExpN1-20261101-090435/`(整目录)+ `G-EFI-config-backup-20261101-090435-pre-ExpN1.plist`(SHA 5aba9229…90fe7)
- 生效内容:boot-args +8 项(nvfb/nvaccel/nvfbheads=4/-nvkmsnosmooth/amfi×2/ipc_control_port_options/gfxrst=4)、csr→430a0000、+AMFIPass.kext 1.4.1、Block IONDRVSupport
- 验证:config 与 Exp-N1 源哈希一致;ocvalidate 零错误;CMP model 注入在位;P630 DeviceProperties 保留(在用机必需,公开版才剥离)
- 安全状态变更(如实):SIP 调整为 430a0000(官方测试值)+ AMFI 参数——**这是 NullMoth 官方要求,已由用户直接下令部署**
- 回滚:`EFI-before-ExpN1-20261101-090435/` 整目录还原 + Reset NVRAM
- 下一步:重启 → collect-intel-fb-evidence.sh(CFL 验证)→ 安装 NullMoth 驱动 → kmutil/Metal 验证

## FIX-7 / BUG-EFI-004 + Picker Timeout(2026-11-01,用户指令"应用所有变更")
- 文件:`<系统 EFI 分区>/EFI/OC/config.plist`(两处)± 构建副本同步
- 修改 1:Lilu.kext 移至 Kernel→Add 链首(其余相对顺序不变)→ BUG-EFI-004 FIXED
- 修改 2:Misc→Boot→Timeout 5 → 10(Picker 倒计时延长,用户反馈"很短")
- 未动:boot-args/csr/Block/P630/CMP/APFS 组合(审计"不动清单")
- 验证:plistlib ✅ / ocvalidate 1.0.8 零错误 ✅ / 构建副本同步 ✅
- 备份:`G-EFI-config-backup-20261101-101722-pre-lilu-timeout.plist`(SHA 7f73fe6b…9205)
- 生效:下次重启
