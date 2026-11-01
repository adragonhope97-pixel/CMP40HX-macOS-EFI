#!/bin/bash
# =====================================================================
# CMP 40HX 一键诊断(macOS 版"bat")
# 双击本文件(或在终端执行 bash 本文件)→ 直接在桌面生成全部诊断 txt
# 只读:不修改系统、不装东西、不重启
# =====================================================================
set -u
D="$HOME/Desktop"
N="CMP40HX"
say(){ echo "✔ 已生成: $1"; }

# 1) 系统与启动参数
{ sw_vers; echo; echo "-- kern.bootargs --"; sysctl kern.bootargs 2>/dev/null; echo "-- nvram boot-args --"; nvram boot-args 2>/dev/null; } > "$D/$N-1-系统与启动参数.txt" 2>&1
say "$N-1-系统与启动参数.txt"

# 2) IORegistry 全量(证据底档)
ioreg -p IOService -w 0 -l > "$D/$N-2-IORegistry全量.txt" 2>&1
say "$N-2-IORegistry全量.txt"
IOREG="$D/$N-2-IORegistry全量.txt"

# 3) 内核扩展加载列表 + NullMoth 四组件
kmutil showloaded --list-only > "$D/$N-3-内核扩展列表.txt" 2>&1
NM=$(grep -ci "nullmoth" "$D/$N-3-内核扩展列表.txt")
{ echo "nullmoth 组件加载数 = $NM (期望 4)"; echo; grep -i "nullmoth" "$D/$N-3-内核扩展列表.txt"; } > "$D/$N-3b-NullMoth组件.txt" 2>&1
say "$N-3-内核扩展列表.txt / $N-3b-NullMoth组件.txt"

# 4) NVIDIA 绑定/启动状态(类实例计数)
{ echo "NVAccel 服务实例: $(grep -c '"IOClass" = "NVAccel"' "$IOREG")";
  echo "NVRM   服务实例: $(grep -c '"IOClass" = "NVRM"' "$IOREG")";
  echo "NVRMFB 帧缓冲  : $(grep -c 'NVRMNVDAFramebuffer' "$IOREG")";
  echo "NVAccelHeadless: $(grep -c 'NVAccelHeadless' "$IOREG")"; } > "$D/$N-4-NVIDIA绑定状态.txt" 2>&1
say "$N-4-NVIDIA绑定状态.txt"

# 5) CMP 40HX 节点子树
grep -n -B4 -A45 "NVIDIA CMP 40HX" "$IOREG" > "$D/$N-5-CMP节点.txt" 2>&1
say "$N-5-CMP节点.txt"

# 6) NVRM / GSP / RmInitAdapter 日志(本次启动)
log show --last boot --style compact --predicate '(eventMessage CONTAINS[c] "NVRM") OR (eventMessage CONTAINS[c] "GSP") OR (eventMessage CONTAINS[c] "RmInitAdapter") OR (eventMessage CONTAINS[c] "NullMoth")' > "$D/$N-6-NVRM与GSP日志.txt" 2>&1
{ echo "相关日志行数: $(wc -l < "$D/$N-6-NVRM与GSP日志.txt" | tr -d ' ')"; echo; grep -iE "RmInitAdapter|GSP|failed|error" "$D/$N-6-NVRM与GSP日志.txt" | tail -15; } > /dev/null
say "$N-6-NVRM与GSP日志.txt"

# 7) 显示与 Metal 枚举
system_profiler SPDisplaysDataType -detailLevel full > "$D/$N-7-显示与Metal.txt" 2>&1
say "$N-7-显示与Metal.txt"

# 8) Intel P630 对照状态
{ echo "CFL FB kext 计数 : $(grep -c 'AppleIntelCFLGraphicsFramebuffer' "$IOREG")";
  echo "IntelAccelerator : $(grep -c 'IntelAccelerator' "$IOREG")";
  echo "IOAccelDevice2   : $(grep -c 'IOAccelDevice2' "$IOREG")";
  echo "IONDRVFramebuffer: $(grep -c 'IONDRVFramebuffer' "$IOREG")";
  echo; echo "-- Metal / VRAM 行 --"; grep -iE "metal|vram" "$D/$N-7-显示与Metal.txt" | head -8; } > "$D/$N-8-Intel状态.txt" 2>&1
say "$N-8-Intel状态.txt"

# 9) sysctl 特性项
sysctl -a 2>/dev/null | grep -iE "nmx|nvaccel|nvrm|gsp" > "$D/$N-9-sysctl.txt" 2>&1
say "$N-9-sysctl.txt"

# 0) 摘要(自动指标,最终判定由助手出具)
{ echo "===== CMP 40HX 诊断摘要(自动指标,仅供判读)=====";
  echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')";
  echo;
  echo "NullMoth 组件加载数  : $NM  (期望 4)";
  echo "NVAccel 服务实例     : $(grep -c '"IOClass" = "NVAccel"' "$IOREG")";
  echo "NVRM 服务实例        : $(grep -c '"IOClass" = "NVRM"' "$IOREG")";
  echo "NVRMNVDAFramebuffer  : $(grep -c 'NVRMNVDAFramebuffer' "$IOREG")";
  echo "CFL FB kext 计数     : $(grep -c 'AppleIntelCFLGraphicsFramebuffer' "$IOREG")";
  echo "IntelAccelerator     : $(grep -c 'IntelAccelerator' "$IOREG")";
  echo "IOAccelDevice2       : $(grep -c 'IOAccelDevice2' "$IOREG")";
  echo "IONDRVFramebuffer    : $(grep -c 'IONDRVFramebuffer' "$IOREG")";
  echo;
  echo "Metal 行(SI)        :"; grep -i "metal" "$D/$N-7-显示与Metal.txt" | head -4;
  echo; echo "详细数据见同目录其余 txt;请整个发回给助手判定。"; } > "$D/$N-0-摘要.txt" 2>&1
say "$N-0-摘要.txt"

echo
echo "================ 全部完成 ================"
echo "桌面上的 $N-*.txt 就是全部证据,整个发回即可。"
open -R "$D/$N-0-摘要.txt" 2>/dev/null || open "$D" 2>/dev/null || true
