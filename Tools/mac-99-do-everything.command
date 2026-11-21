#!/bin/bash
# =====================================================================
#  mac-99-do-everything.command   (v1, 2026-11-21)
#
#  在 macOS 里双击运行, 一次完成:
#    1) 检查工具链
#    2) 编译骨架 kext (已编译则跳过)
#    3) 复制 kext 到 U 盘的 EFI/OC/Kexts/
#    4) 备份 config.plist (带时间戳, 存在 U 盘上)
#    5) 在 Kernel > Add 里加入 CMP40HXAccelerator.kext
#    6) 校验: plutil -lint + 逐项确认其它配置未被改动
#    7) 打印重启后的取证命令
#
#  回滚: 双击 mac-99-revert.command (同目录)
# =====================================================================
set +e

KEXT_NAME="CMP40HXAccelerator.kext"
EXPECT_SHA="a3f61d6b195dfc80ef7bd58e3bf7077605ab04ae35f8a0461d8a8f45f1252fb4"
PROJ="$HOME/Desktop/CMP40HX-Metal-Skeleton"
TS="$(date '+%Y%m%d-%H%M%S')"
LOG="$HOME/Desktop/CMP40HX-ALLINONE-$TS.txt"

exec > >(tee "$LOG") 2>&1

say() { echo; echo "== $* =="; }

say "CMP40HX 一键部署 $TS"
echo "日志: $LOG"

# ---------------------------------------------------------------- 1. 找 U 盘
say "1/7 定位 U 盘"
DST_ROOT=""
for cand in "/Volumes/<USB_VOLUME>" "/Volumes/<USB_VOLUME>"; do
  if [ -f "$cand/EFI/OC/config.plist" ]; then DST_ROOT="$cand"; break; fi
done
if [ -z "$DST_ROOT" ]; then
  for v in /Volumes/*; do
    [ -f "$v/EFI/OC/config.plist" ] && { DST_ROOT="$v"; break; }
  done
fi
if [ -z "$DST_ROOT" ]; then
  echo "FAIL: 没找到含 EFI/OC/config.plist 的卷"
  echo "当前卷:"; ls -1 /Volumes/ 2>/dev/null
  read -r -p "按 Enter 退出..."; exit 1
fi
CFG="$DST_ROOT/EFI/OC/config.plist"
KEXTS="$DST_ROOT/EFI/OC/Kexts"
echo "OK: $DST_ROOT"
echo "    config: $CFG"

# ---------------------------------------------------------------- 2. 工具链
say "2/7 工具链"
if ! xcode-select -p >/dev/null 2>&1; then
  echo "FAIL: 缺 Xcode CLT, 先跑 xcode-select --install"
  read -r -p "按 Enter 退出..."; exit 1
fi
echo "OK: $(xcode-select -p)"
command -v python3 >/dev/null || { echo "FAIL: 缺 python3"; read -r -p "按 Enter 退出..."; exit 1; }
echo "OK: python3 $(python3 -V 2>&1 | awk '{print $2}')"

# ---------------------------------------------------------------- 3. 编译
say "3/7 编译 kext"
# 若 U 盘上带了最新源码, 先同步进工程(含 __kmod_info 修复)
if [ -f "$DST_ROOT/src/CMP40HXAccelerator.cpp" ]; then
  mkdir -p "$PROJ/src"
  cp "$DST_ROOT/src/"* "$PROJ/src/" 2>/dev/null
  [ -f "$DST_ROOT/build.sh" ] && cp "$DST_ROOT/build.sh" "$PROJ/build.sh"
  echo "已同步 U 盘上的最新源码 + build.sh 到工程目录"
fi
# 总是重新编译: 旧产物可能是缺 __kmod_info 的坏版本(2026-11-21 实测)
rm -rf "$PROJ/build"
echo "开始编译..."
( cd "$PROJ" && chmod +x build.sh && ./build.sh ) || {
  echo "FAIL: 编译失败, 见上方输出"
  read -r -p "按 Enter 退出..."; exit 1
}
SRC="$PROJ/build/$KEXT_NAME"
[ -d "$SRC" ] || { echo "FAIL: 找不到 $SRC"; read -r -p "按 Enter 退出..."; exit 1; }
SRC_SHA=$(shasum -a 256 "$SRC/Contents/MacOS/CMP40HXAccelerator" | awk '{print $1}')
echo "源 kext SHA256: $SRC_SHA"

# 关键校验: 必须有 __kmod_info 段, 否则内核不会加载(2026-11-21 踩过的坑)
if otool -l "$SRC/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null | grep -q "__kmod_info"; then
  echo "OK: __kmod_info 段存在"
else
  echo "FAIL: 缺 __kmod_info 段 —— 内核不会加载这个 kext"
  echo "      说明源码里的 KMOD_EXPLICIT_DECL 没生效, 停止部署"
  read -r -p "按 Enter 退出..."; exit 1
fi

# ---------------------------------------------------------------- 4. 复制 kext
say "4/7 复制 kext 到 U 盘"
# 同时把最新的取证脚本同步进工程目录(若 U 盘上有)
if [ -f "$DST_ROOT/verify-skeleton.sh" ]; then
  cp "$DST_ROOT/verify-skeleton.sh" "$PROJ/tests/verify-skeleton.sh" && echo "已更新 tests/verify-skeleton.sh (v2)"
fi
rm -rf "$KEXTS/$KEXT_NAME"
cp -R "$SRC" "$KEXTS/" || { echo "FAIL: 复制失败"; read -r -p "按 Enter 退出..."; exit 1; }
DST_SHA=$(shasum -a 256 "$KEXTS/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" | awk '{print $1}')
echo "目标 SHA256: $DST_SHA"
if [ "$DST_SHA" = "$SRC_SHA" ]; then echo "OK: 复制完整"; else echo "WARN: SHA 不一致(U 盘写入异常)"; fi

# ---------------------------------------------------------------- 5. 备份 config
say "5/7 备份 config.plist"
BAK="$CFG.bak-$TS"
cp "$CFG" "$BAK" || { echo "FAIL: 备份失败, 中止(不动原文件)"; read -r -p "按 Enter 退出..."; exit 1; }
echo "备份: $BAK"
CFG_SHA_BEFORE=$(shasum -a 256 "$CFG" | awk '{print $1}')
echo "改前 SHA256: $CFG_SHA_BEFORE"

# ---------------------------------------------------------------- 6. 加条目
say "6/7 写入 Kernel > Add"
python3 - "$CFG" "$KEXT_NAME" <<'PY'
import sys, plistlib
cfg, name = sys.argv[1], sys.argv[2]
with open(cfg, 'rb') as f:
    d = plistlib.load(f)

add = d.setdefault('Kernel', {}).setdefault('Add', [])
if any(k.get('BundlePath') == name for k in add):
    print("ALREADY: 条目已存在, 未重复添加")
else:
    add.append({
        "Arch": "Any",
        "BundlePath": name,
        "Comment": "PMC probe v0.2 (CMP 40HX)",
        "Enabled": True,
        "ExecutablePath": "Contents/MacOS/CMP40HXAccelerator",
        "MaxKernel": "",
        "MinKernel": "",
        "PlistPath": "Contents/Info.plist",
    })
    with open(cfg, 'wb') as f:
        plistlib.dump(d, f, sort_keys=False)
    print("ADDED: 已加入 %s (共 %d 条)" % (name, len(add)))

# 自检: 确认写入后仍可读且条目存在
with open(cfg, 'rb') as f:
    v = plistlib.load(f)
ok = any(k.get('BundlePath') == name and k.get('Enabled') for k in v['Kernel']['Add'])
print("VERIFY: 条目可读且已启用 =", ok)
sys.exit(0 if ok else 3)
PY
RC=$?
if [ $RC -ne 0 ]; then
  echo "FAIL: 写入后自检失败, 正在恢复备份"
  cp "$BAK" "$CFG"
  echo "已恢复: $CFG"
  read -r -p "按 Enter 退出..."; exit 1
fi

# plutil 语法校验
say "plutil 语法校验"
if plutil -lint "$CFG"; then echo "OK: plist 结构合法"; else
  echo "FAIL: plist 非法, 恢复备份"
  cp "$BAK" "$CFG"; read -r -p "按 Enter 退出..."; exit 1
fi

# ---------------------------------------------------------------- 6.5 同步内置 ESP
say "6.5/7 同步到内置 ESP(消除'实际从哪个 ESP 引导'的不确定性)"
# / 在 APFS 合成卷上, "Part of Whole" 给的是 disk5(合成容器), 必须回溯物理存储 disk4s2 → disk4
ROOTVOL=$(diskutil info / 2>/dev/null | awk -F: '/Part of Whole/{gsub(/ /,"",$2); print $2}')
PHYS=$(diskutil info "$ROOTVOL" 2>/dev/null | awk -F: '/APFS Physical Store/{gsub(/ /,"",$2); print $2}')
if [ -n "$PHYS" ]; then BASE=$(printf '%s' "$PHYS" | sed 's/s[0-9]*$//'); else BASE="$ROOTVOL"; fi
echo "根卷: ${ROOTVOL:-?}  物理存储: ${PHYS:-?}  物理盘: ${BASE:-?}"
EFIPART=$(diskutil list "/dev/$BASE" 2>/dev/null | awk '/EFI EFI/{print $NF}' | head -1)
# 兜底: 找同时含 Apple_APFS 与 EFI 的物理盘
if [ -z "$EFIPART" ]; then
  for d in $(diskutil list 2>/dev/null | grep -E "^/dev/disk[0-9]+" | awk '{print $1}'); do
    L=$(diskutil list "$d" 2>/dev/null)
    if echo "$L" | grep -q "Apple_APFS" && echo "$L" | grep -q "EFI EFI"; then
      EFIPART=$(echo "$L" | awk '/EFI EFI/{print $NF}' | head -1); break
    fi
  done
fi
echo "该盘的 ESP: ${EFIPART:-<未找到>}"
if [ -n "$EFIPART" ]; then
  sudo diskutil mount "$EFIPART" >/dev/null 2>&1
  MP=$(diskutil info "$EFIPART" 2>/dev/null | awk -F: '/Mount Point/{gsub(/^ +/,"",$2); print $2}')
  if [ -n "$MP" ] && [ -d "$MP/EFI/OC" ]; then
    [ -f "$MP/EFI/OC/config.plist" ] && cp "$MP/EFI/OC/config.plist" "$MP/EFI/OC/config.plist.bak-$TS"
    cp "$CFG" "$MP/EFI/OC/config.plist"
    mkdir -p "$MP/EFI/OC/Kexts"
    rm -rf "$MP/EFI/OC/Kexts/$KEXT_NAME"
    cp -R "$KEXTS/$KEXT_NAME" "$MP/EFI/OC/Kexts/" 2>/dev/null
    echo "已同步到内置 ESP: $MP"
    echo "  U 盘 config SHA : $(shasum -a 256 "$CFG" | awk '{print $1}')"
    echo "  内置 config SHA : $(shasum -a 256 "$MP/EFI/OC/config.plist" | awk '{print $1}')"
    echo "  U 盘 kext SHA   : $(shasum -a 256 "$KEXTS/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" | awk '{print $1}')"
    echo "  内置 kext SHA   : $(shasum -a 256 "$MP/EFI/OC/Kexts/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null | awk '{print $1}')"
  else
    echo "WARN: 内置 ESP 未挂载或结构异常, 跳过(不影响 U 盘部署)"
  fi
else
  echo "WARN: 未找到内置 ESP, 跳过(不影响 U 盘部署)"
fi

# ---------------------------------------------------------------- 7. 差异核对
say "7/7 差异核对 (除 Kernel>Add 外不应有任何变化)"
python3 - "$BAK" "$CFG" <<'PY'
import sys, plistlib
old = plistlib.load(open(sys.argv[1], 'rb'))
new = plistlib.load(open(sys.argv[2], 'rb'))

oa = [k.get('BundlePath') for k in old['Kernel']['Add']]
na = [k.get('BundlePath') for k in new['Kernel']['Add']]
print("Kernel>Add: %d -> %d" % (len(oa), len(na)))
print("新增条目:", [x for x in na if x not in oa])
print("丢失条目:", [x for x in oa if x not in na])

def ba(d):
    return d['NVRAM']['Add']['7C436110-AB2A-4BBB-A880-FE41995C9F82'].get('boot-args')
print("boot-args 未变:", ba(old) == ba(new))
print("DeviceProperties 未变:", old.get('DeviceProperties') == new.get('DeviceProperties'))
print("ACPI 未变:", old.get('ACPI') == new.get('ACPI'))
print("SMBIOS 未变:", old.get('PlatformInfo') == new.get('PlatformInfo'))
print("Misc 未变:", old.get('Misc') == new.get('Misc'))
PY

CFG_SHA_AFTER=$(shasum -a 256 "$CFG" | awk '{print $1}')
echo
echo "改后 SHA256: $CFG_SHA_AFTER"

# ---------------------------------------------------------------- 完成
say "全部完成"
cat <<EOF
已启用: $KEXT_NAME (ProbeScore 40000, PMC 探针 v0.2)
备份  : $BAK

下一步:
  1) 重启 Mac
  2) 桌面出来后, 终端执行:
       bash ~/Desktop/CMP40HX-Metal-Skeleton/tests/verify-skeleton.sh
  3) 把生成的 CMP40HX-SKELETON-*.txt 发回分析

预期: 启动日志出现 "CMP40HX-Probe: sample 0: boot0=0x..."
      ioreg 里 CMP40HX,verdict = GPU_ALIVE 或 GPU_NOT_RESPONDING

如果启动失败(卡住/panic):
  - 回 Windows, 让 AI 从 U 盘备份恢复
  - 或在 macOS 里双击同目录的 mac-99-revert.command
EOF
read -r -p "按 Enter 退出..."
