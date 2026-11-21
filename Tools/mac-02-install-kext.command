#!/bin/bash
# mac-02-install-kext.command  v3
# 用法: 在 macOS 的访达里双击本文件(会打开终端自动运行), 或终端执行
#       bash "/Volumes/<USB_VOLUME>/mac-02-install-kext.command"
#
# v3 加固:
#   - 自动扫描 /Volumes 找含 EFI/OC/Kexts 的卷(不写死卷标)
#   - 自动在 ~/Desktop、~/Downloads 下搜索编译产物 CMP40HXAccelerator.kext
#   - 找不到时打印诊断信息, 不静默失败
#   - 只复制文件, 不修改 config.plist
set +e
EXPECT_SHA="a3f61d6b195dfc80ef7bd58e3bf7077605ab04ae35f8a0461d8a8f45f1252fb4"

echo "===== CMP40HX KEXT INSTALL (v3) ====="
echo "时间: $(date)"
echo "用户: $(whoami)"
echo

# ---------- 1. 找目标卷 ----------
DST_DIR=""
for cand in "/Volumes/<USB_VOLUME>" "/Volumes/<USB_VOLUME>"; do
  if [ -d "$cand/EFI/OC/Kexts" ]; then DST_DIR="$cand/EFI/OC/Kexts"; break; fi
done
if [ -z "$DST_DIR" ]; then
  for v in /Volumes/*; do
    [ -d "$v/EFI/OC/Kexts" ] && { DST_DIR="$v/EFI/OC/Kexts"; break; }
  done
fi
if [ -z "$DST_DIR" ]; then
  echo "ERROR: 没找到含 EFI/OC/Kexts 的卷。"
  echo "当前挂载的卷:"; ls -1 /Volumes/ 2>/dev/null
  echo
  echo "请确认 U 盘已插好(访达左侧能看到), 然后重跑。"
  read -r -p "按 Enter 退出..."; exit 1
fi
echo "[1] 目标: $DST_DIR"

# ---------- 2. 找源 kext ----------
SRC=""
for p in \
  "$HOME/Desktop/CMP40HX-Metal-Skeleton/build/CMP40HXAccelerator.kext" \
  "$HOME/Downloads/CMP40HX-Metal-Skeleton/build/CMP40HXAccelerator.kext" \
  "/Volumes/<USB_VOLUME>/CMP40HXAccelerator.kext" ; do
  [ -d "$p" ] && { SRC="$p"; break; }
done

if [ -z "$SRC" ]; then
  echo "[2] 常见路径没找到, 开始搜索(最多 4 层深)..."
  FOUND=$(find "$HOME/Desktop" "$HOME/Downloads" -maxdepth 4 -name "CMP40HXAccelerator.kext" -type d 2>/dev/null | head -3)
  if [ -n "$FOUND" ]; then
    SRC=$(printf '%s\n' "$FOUND" | head -1)
    echo "    找到: $SRC"
  fi
fi

if [ -z "$SRC" ]; then
  echo "ERROR: 找不到编译产物 CMP40HXAccelerator.kext"
  echo
  echo "请先编译(只需一次):"
  echo "  cd ~/Desktop/CMP40HX-Metal-Skeleton && ./mac-01-build.command"
  echo
  echo "当前桌面内容:"; ls -1 "$HOME/Desktop" 2>/dev/null | head -20
  read -r -p "按 Enter 退出..."; exit 1
fi
echo "[2] 源: $SRC"

# ---------- 3. 复制 ----------
rm -rf "$DST_DIR/CMP40HXAccelerator.kext"
cp -R "$SRC" "$DST_DIR/" || { echo "ERROR: 复制失败(U 盘满或只读)"; read -r -p "按 Enter 退出..."; exit 1; }
echo "[3] 已复制到 $DST_DIR"

# ---------- 4. 校验 ----------
ACTUAL=$(shasum -a 256 "$DST_DIR/CMP40HXAccelerator.kext/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null | awk '{print $1}')
echo "[4] 目标 SHA256: ${ACTUAL:-<读取失败>}"
if [ "$ACTUAL" = "$EXPECT_SHA" ]; then
  echo "    OK: 与 Mac 构建产物一致"
else
  echo "    WARN: 与预期不一致 (预期 $EXPECT_SHA)"
  echo "    可能是 U 盘写入异常 —— 建议重插 U 盘后重跑"
fi

# ---------- 5. 结果 ----------
echo
echo "[5] Kexts 目录:"
ls -1 "$DST_DIR"
echo
echo "完成。关机 → 回 Windows → 告诉 AI「kext 已就位」。"
echo "(本脚本没改 config.plist, 现在重启不会加载它)"
read -r -p "按 Enter 退出..."
