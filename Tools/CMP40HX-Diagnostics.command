#!/bin/bash
# =====================================================================
# CMP 40HX 一键诊断 v3
# 输出到 ~/Downloads(不在 iCloud 桌面同步范围,避免占位文件问题)
# 双击本文件,或终端执行:bash 本文件路径
# 只读:不修改系统、不装东西、不重启;产出单个结果 txt + 证据目录
# =====================================================================
set -u
OUT="$HOME/Downloads/CMP40HX-RESULT-$(date +%m%d-%H%M).txt"
EV="$HOME/Downloads/CMP40HX-EVIDENCE-$(date +%m%d-%H%M)"
mkdir -p "$EV"

{
  date
  sw_vers
  echo; echo "-- kern.bootargs --"; sysctl kern.bootargs 2>/dev/null
  echo "-- nvram boot-args --"; nvram boot-args 2>/dev/null
} > "$OUT" 2>&1

{
  echo "== NullMoth 四组件 =="
  kmutil showloaded --list-only 2>/dev/null | grep -i nullmoth
  echo "(以上为全部 nullmoth 组件;空 = 未加载)"
} >> "$OUT" 2>&1

ioreg -p IOService -w 0 -l > "$EV/ioreg-full.txt" 2>&1
IOREG="$EV/ioreg-full.txt"

{
  echo "== IORegistry 关键类实例计数 =="
  for k in '"IOClass" = "NVAccel"' '"IOClass" = "NVRM"' 'NVRMNVDAFramebuffer' 'NVAccelHeadless' 'AppleIntelCFLGraphicsFramebuffer' 'IntelAccelerator' 'IOAccelDevice2' 'IONDRVFramebuffer'; do
    echo "  $k = $(grep -cF "$k" "$IOREG")"
  done
} >> "$OUT" 2>&1

{
  echo "== CMP 40HX 节点子树 =="
  grep -n -B4 -A45 "NVIDIA CMP 40HX" "$IOREG"
} >> "$OUT" 2>&1

{
  echo "== Intel IGPU 节点段 =="
  grep -n -A22 "IGPU@2" "$IOREG" | head -30
} >> "$OUT" 2>&1

{
  echo "== SPDisplays(Metal/VRAM/分辨率)==="
  system_profiler SPDisplaysDataType -detailLevel full 2>/dev/null
} >> "$OUT" 2>&1

{
  echo "== GSP/RmInitAdapter/NVRM 日志(本次启动,末 60 行)==="
  log show --last boot --style compact --predicate '(eventMessage CONTAINS[c] "NVRM") OR (eventMessage CONTAINS[c] "GSP") OR (eventMessage CONTAINS[c] "RmInitAdapter") OR (eventMessage CONTAINS[c] "NullMoth")' 2>/dev/null | tail -60
} >> "$OUT" 2>&1

cp "$IOREG" "$EV/" 2>/dev/null
echo
echo "================ 全部完成 ================"
echo "结果文件: $OUT"
echo "证据目录: $EV"
echo "把这两个发回给助手判定即可。"
open -R "$OUT" 2>/dev/null || true
