#!/bin/bash
# verify-skeleton.sh v2 —— Mac 端骨架加载结果取证(只读)
# v2 修正: 日志过滤词改为 CMP40HX(实际 tag 是 CMP40HX-Probe); 增加 kmutil 加载检查
set +e
TS="$(date '+%Y%m%d-%H%M%S')"
OUT="$HOME/Desktop/CMP40HX-SKELETON-$TS.txt"

{
echo "===== CMP40HX SKELETON VERIFY v2 $TS ====="
echo "macOS: $(sw_vers -productVersion) build $(sw_vers -buildVersion)"
echo

echo "--- [0] kext 是否被内核加载(最关键) ---"
kmutil showloaded --list-only 2>/dev/null | grep -i "cmp40hx\|skeleton" || echo "(未在已加载列表中找到 —— kext 未被加载)"
echo "exit=$?"

echo
echo "--- [1] 类实例是否存在 ---"
ioreg -r -c CMP40HXAccelerator -l -w0
echo "exit=$?"

echo
echo "--- [2] 关键属性 ---"
ioreg -r -c CMP40HXAccelerator -l -w0 | grep -E "CMP40HX,|MetalPluginName|IOClass|IOProbeScore"
echo "exit=$?"

echo
echo "--- [3] PCI 节点归属(谁在驱动 1f0b) ---"
ioreg -lw0 -p IOService | grep -i -B3 -A3 "pci10de,1f0b"
echo "exit=$?"

echo
echo "--- [3b] 该节点的 IOClass / 驱动类 ---"
ioreg -lw0 -p IOService | grep -i -B12 "pci10de,1f0b" | grep -E '"\+(IOClass|IOMatchCategory|IOProbeScore|IOProviderClass)"' 
echo "exit=$?"

echo
echo "--- [4] 内核日志(CMP40HX 相关, 本次启动 15 分钟) ---"
log show --last 30m --predicate 'eventMessage CONTAINS "CMP40HX"' 2>/dev/null | tail -40
echo "exit=$?"

echo
echo "--- [4b] 内核日志(kext 加载失败类消息) ---"
log show --last 30m --predicate 'eventMessage CONTAINS[c] "CMP40HXAccelerator" OR eventMessage CONTAINS[c] "kmod_info" OR eventMessage CONTAINS[c] "kext load"' 2>/dev/null | tail -20
echo "exit=$?"

echo
echo "--- [5] NVRM 抢占对照 ---"
echo "NVRMFBClaim 出现次数: $(ioreg -lw0 | grep -c NVRMFBClaim)"
echo "NVRM 类实例:"
ioreg -r -c NVRM -l -w0 2>/dev/null | grep -E '"IOClass"|"CMP40HX' | head -5
echo "exit=$?"

echo
echo "===== END ====="
} > "$OUT" 2>&1

echo "报告: $OUT"
shasum -a 256 "$OUT"
read -r -p "按 Enter 退出..."
