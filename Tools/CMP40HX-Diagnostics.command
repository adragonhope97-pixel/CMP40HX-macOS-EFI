#!/bin/bash
# =====================================================================
# CMP 40HX 一键诊断(只读,不改系统、不装东西、不重启)
# 用法之一:终端里执行  bash ~/Downloads/CMP40HX-Diagnostics.command
# 证据目录会自动生成在桌面,结束后自动打开
# =====================================================================
set -u
OUT="$HOME/Desktop/CMP40HX-Diagnostics-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
exec > >(tee "$OUT/SUMMARY.txt") 2>&1

sec(){ echo; echo "========== $* =========="; }

sec "0) 系统与启动参数"
sw_vers
sysctl kern.bootargs 2>/dev/null
nvram boot-args 2>/dev/null

sec "1) NullMoth 四组件是否加载"
KM=$(kmutil showloaded --list-only 2>/dev/null | grep -i "nullmoth")
echo "$KM"
if [ -n "$KM" ]; then
  N=$(echo "$KM" | grep -c "com.nullmoth")
  echo "[指示] nullmoth 组件加载数 = $N (期望 4)"
else
  echo "[指示] 未加载(0)"
fi

sec "2) IORegistry 全量快照"
ioreg -p IOService -w 0 -l > "$OUT/ioreg-full.txt" 2>/dev/null
IOREG="$OUT/ioreg-full.txt"
wc -l "$IOREG"

sec "3) NVIDIA 绑定/启动状态"
echo "NVAccel 服务实例: $(grep -c '"IOClass" = "NVAccel"' "$IOREG")"
echo "NVRM   服务实例: $(grep -c '"IOClass" = "NVRM"' "$IOREG")"
echo "NVRMFB 帧缓冲  : $(grep -c 'NVRMNVDAFramebuffer' "$IOREG")"
echo "NVAccelHeadless: $(grep -c 'NVAccelHeadless' "$IOREG")"

sec "4) 无头/特性 sysctl"
sysctl -a 2>/dev/null | grep -iE "nmx|nvaccel|nvrm|gsp" | head -10
echo "(空 = 相应 sysctl 未注册)"

sec "5) CMP 40HX 节点子树"
grep -n -B4 -A45 "NVIDIA CMP 40HX" "$IOREG" > "$OUT/cmp-node.txt" 2>/dev/null
head -60 "$OUT/cmp-node.txt"

sec "6) GSP / RmInitAdapter / NVRM 日志(本次启动)"
log show --last boot --style compact --predicate '(eventMessage CONTAINS[c] "NVRM") OR (eventMessage CONTAINS[c] "GSP") OR (eventMessage CONTAINS[c] "RmInitAdapter") OR (eventMessage CONTAINS[c] "NullMoth") OR (eventMessage CONTAINS[c] "nvrm")' > "$OUT/log-nv.txt" 2>/dev/null
echo "相关日志行数: $(wc -l < "$OUT/log-nv.txt" | tr -d ' ')"
grep -iE "RmInitAdapter|GSP|failed|error" "$OUT/log-nv.txt" | tail -15

sec "7) Metal / 显示枚举"
system_profiler SPDisplaysDataType -detailLevel full > "$OUT/sp-displays.txt" 2>/dev/null
grep -iE "chipset|model|metal|vram|resolution|ui looks like" "$OUT/sp-displays.txt"

sec "8) Intel P630 状态(对照)"
echo "CFL FB 类实例    : $(grep -c 'AppleIntelCFLGraphicsFramebuffer' "$IOREG")"
echo "IntelAccelerator : $(grep -c 'IntelAccelerator' "$IOREG")"
echo "IOAccelDevice2   : $(grep -c 'IOAccelDevice2' "$IOREG")"
echo "IONDRVFramebuffer: $(grep -c 'IONDRVFramebuffer' "$IOREG")"
grep -iE "metal|vram" "$OUT/sp-displays.txt" | head -6

sec "9) 证据文件清单"
ls -la "$OUT"

echo
echo "========== 完成 =========="
echo "证据目录: $OUT"
echo "请把整个目录(或至少 SUMMARY.txt)发回给助手判定。"
open "$OUT" 2>/dev/null || true
