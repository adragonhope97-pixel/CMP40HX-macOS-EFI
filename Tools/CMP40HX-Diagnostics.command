#!/bin/bash
# =====================================================================
# CMP 40HX 一键诊断(macOS 版"bat")v2 —— ASCII 文件名 + 自动打包 zip
# 双击本文件(或终端执行 bash 本文件)→ 直接在桌面生成全部诊断 txt
# 并自动打成一个 zip(把这个 zip 发回即可,内容不会在传输中损坏)
# 只读:不修改系统、不装东西、不重启
# =====================================================================
set -u
OUT="$HOME/Desktop/CMP40HX-Diagnostics-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

sec(){ echo; echo "===== $* ====="; }

# 1) 系统与启动参数
{ sw_vers; echo; echo "-- kern.bootargs --"; sysctl kern.bootargs 2>/dev/null; echo "-- nvram boot-args --"; nvram boot-args 2>/dev/null; } > "$OUT/1-system-bootargs.txt" 2>&1

# 2) IORegistry 全量(证据底档)
ioreg -p IOService -w 0 -l > "$OUT/2-ioreg-full.txt" 2>&1
IOREG="$OUT/2-ioreg-full.txt"

# 3) 内核扩展加载列表 + NullMoth 四组件
kmutil showloaded --list-only > "$OUT/3-kexts-loaded.txt" 2>&1
NM=$(grep -ci "nullmoth" "$OUT/3-kexts-loaded.txt")
{ echo "nullmoth components loaded = $NM (expect 4)"; echo; grep -i "nullmoth" "$OUT/3-kexts-loaded.txt"; } > "$OUT/3b-nullmoth-components.txt" 2>&1

# 4) NVIDIA 绑定/启动状态(类实例计数)
{ echo "NVAccel service instances : $(grep -c '"IOClass" = "NVAccel"' "$IOREG")";
  echo "NVRM   service instances  : $(grep -c '"IOClass" = "NVRM"' "$IOREG")";
  echo "NVRMFB framebuffer        : $(grep -c 'NVRMNVDAFramebuffer' "$IOREG")";
  echo "NVAccelHeadless flag      : $(grep -c 'NVAccelHeadless' "$IOREG")"; } > "$OUT/4-nvidia-bind.txt" 2>&1

# 5) CMP 40HX 节点子树
grep -n -B4 -A45 "NVIDIA CMP 40HX" "$IOREG" > "$OUT/5-cmp-node.txt" 2>&1

# 6) NVRM / GSP / RmInitAdapter 日志(本次启动)
log show --last boot --style compact --predicate '(eventMessage CONTAINS[c] "NVRM") OR (eventMessage CONTAINS[c] "GSP") OR (eventMessage CONTAINS[c] "RmInitAdapter") OR (eventMessage CONTAINS[c] "NullMoth")' > "$OUT/6-log-nvrm-gsp.txt" 2>&1

# 7) 显示与 Metal 枚举
system_profiler SPDisplaysDataType -detailLevel full > "$OUT/7-sp-displays.txt" 2>&1

# 8) Intel P630 对照
{ echo "CFL FB kext count    : $(grep -c 'AppleIntelCFLGraphicsFramebuffer' "$IOREG")";
  echo "IntelAccelerator     : $(grep -c 'IntelAccelerator' "$IOREG")";
  echo "IOAccelDevice2       : $(grep -c 'IOAccelDevice2' "$IOREG")";
  echo "IONDRVFramebuffer    : $(grep -c 'IONDRVFramebuffer' "$IOREG")";
  echo; echo "-- Metal / VRAM lines --"; grep -iE "metal|vram" "$OUT/7-sp-displays.txt" | head -8; } > "$OUT/8-intel-status.txt" 2>&1

# 9) sysctl 特性项
sysctl -a 2>/dev/null | grep -iE "nmx|nvaccel|nvrm|gsp" > "$OUT/9-sysctl.txt" 2>&1

# 0) 摘要(自动指标;最终判定由助手出具)
{ echo "===== CMP 40HX diagnostics summary (auto indicators) =====";
  echo "generated: $(date '+%Y-%m-%d %H:%M:%S')";
  echo;
  echo "nullmoth components loaded : $NM  (expect 4)";
  echo "NVAccel service instances  : $(grep -c '"IOClass" = "NVAccel"' "$IOREG")";
  echo "NVRM service instances     : $(grep -c '"IOClass" = "NVRM"' "$IOREG")";
  echo "NVRMNVDAFramebuffer        : $(grep -c 'NVRMNVDAFramebuffer' "$IOREG")";
  echo "CFL FB kext count          : $(grep -c 'AppleIntelCFLGraphicsFramebuffer' "$IOREG")";
  echo "IntelAccelerator           : $(grep -c 'IntelAccelerator' "$IOREG")";
  echo "IOAccelDevice2             : $(grep -c 'IOAccelDevice2' "$IOREG")";
  echo "IONDRVFramebuffer          : $(grep -c 'IONDRVFramebuffer' "$IOREG")";
  echo;
  echo "Metal lines (SPDisplays):"; grep -i "metal" "$OUT/7-sp-displays.txt" | head -4;
  echo; echo "Send the whole folder (or the auto-made zip on Desktop) back for analysis."; } > "$OUT/0-SUMMARY.txt" 2>&1

# 打包成单个 zip(避免中文文件名传输问题)
ZIP="$HOME/Desktop/$(basename "$OUT").zip"
(cd "$HOME/Desktop" && zip -q -r "$(basename "$ZIP")" "$(basename "$OUT")" 2>/dev/null) || ditto -c -k --keepParent "$OUT" "$ZIP" 2>/dev/null

echo
echo "================ 全部完成 ================"
echo "证据目录: $OUT"
echo "打包文件: $ZIP   ← 把这个 zip 发回即可"
ls -la "$OUT" | head -16
[ -f "$ZIP" ] && echo "zip 校验: $(sha256sum "$ZIP" | cut -c1-16)…"
open -R "$OUT/0-SUMMARY.txt" 2>/dev/null || open "$HOME/Desktop" 2>/dev/null || true
