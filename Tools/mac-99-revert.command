#!/bin/bash
# =====================================================================
#  mac-99-revert.command   (v1, 2026-11-21)
#  回滚: 从 U 盘上最新的 config.plist.bak-* 恢复, 并删除骨架 kext
#  在 macOS 里双击运行即可; 也可以在 Windows 侧让 AI 手工恢复
# =====================================================================
set +e
KEXT_NAME="CMP40HXAccelerator.kext"
TS="$(date '+%Y%m%d-%H%M%S')"

echo "===== CMP40HX REVERT $TS ====="

# 找 U 盘
DST_ROOT=""
for cand in "/Volumes/<USB_VOLUME>" "/Volumes/<USB_VOLUME>"; do
  [ -f "$cand/EFI/OC/config.plist" ] && { DST_ROOT="$cand"; break; }
done
if [ -z "$DST_ROOT" ]; then
  for v in /Volumes/*; do
    [ -f "$v/EFI/OC/config.plist" ] && { DST_ROOT="$v"; break; }
  done
fi
[ -z "$DST_ROOT" ] && { echo "FAIL: 找不到 U 盘"; ls -1 /Volumes/; read -r -p "按 Enter 退出..."; exit 1; }
CFG="$DST_ROOT/EFI/OC/config.plist"
KEXTS="$DST_ROOT/EFI/OC/Kexts"
echo "U 盘: $DST_ROOT"

# 找最新备份
BAK=$(ls -1t "$CFG".bak-* 2>/dev/null | head -1)
if [ -z "$BAK" ]; then
  echo "FAIL: 没有找到 config.plist.bak-* 备份"
  echo "可用的文件:"; ls -1 "$DST_ROOT/EFI/OC/" | grep -i config
  read -r -p "按 Enter 退出..."; exit 1
fi
echo "使用备份: $BAK"
echo "备份 SHA256: $(shasum -a 256 "$BAK" | awk '{print $1}')"

# 恢复
cp "$CFG" "$CFG.before-revert-$TS"
cp "$BAK" "$CFG" || { echo "FAIL: 恢复失败"; read -r -p "按 Enter 退出..."; exit 1; }
echo "已恢复 config.plist"
plutil -lint "$CFG" || echo "WARN: plutil 校验未通过, 请人工检查"

# 删除 kext
if [ -d "$KEXTS/$KEXT_NAME" ]; then
  rm -rf "$KEXTS/$KEXT_NAME"
  echo "已删除 $KEXT_NAME"
else
  echo "$KEXT_NAME 不存在(无需删除)"
fi

echo
echo "完成。当前 config SHA256: $(shasum -a 256 "$CFG" | awk '{print $1}')"
echo "预期基线值: 43182d0baeb832cf8781405365cbda5ba57efdbb6ed7e2ebad2322c47b89ebe4"
echo "现在可以正常重启。"
read -r -p "按 Enter 退出..."
