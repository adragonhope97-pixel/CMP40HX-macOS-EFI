#!/bin/bash
# build.sh —— CMP40HX 自研 kext 骨架构建脚本
# 必须在 macOS + Xcode Command Line Tools 环境执行(Windows 侧无法编译)
# 用法: ./build.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
KEXT_NAME="CMP40HXAccelerator.kext"
BUILD="$SRC_DIR/build"
SDK="$(xcrun --show-sdk-path)"
KERNEL_HDR="$SDK/System/Library/Frameworks/Kernel.framework/Headers"

echo "== CMP40HX skeleton build =="
echo "SDK: $SDK"
[ -d "$KERNEL_HDR" ] || { echo "ERROR: Kernel.framework headers 不存在,请安装 Xcode CLT"; exit 1; }

rm -rf "$BUILD"
mkdir -p "$BUILD/$KEXT_NAME/Contents/MacOS"

echo "-- compile --"
clang++ -std=gnu++17 -arch x86_64 -mkernel \
  -fapple-kext -fno-rtti -fno-exceptions -fno-builtin -fno-common \
  -nostdinc++ -D KERNEL -D KERNEL_PRIVATE \
  -Wno-designated-init -Wno-c++20-designator \
  -I"$KERNEL_HDR" \
  -c "$SRC_DIR/src/CMP40HXAccelerator.cpp" \
  -o "$BUILD/CMP40HXAccelerator.o"

echo "-- link --"
# -sectcreate __TEXT __info_plist: 把 Info.plist 也嵌进二进制(Xcode kext 的默认行为),
# 让 kext 结构更标准; OpenCore 注入时仍以磁盘上的 PlistPath 为准。
clang++ -arch x86_64 -mkernel -nostdlib -r -Wl,-kext \
  -Wl,-sectcreate,__TEXT,__info_plist,"$SRC_DIR/src/Info.plist" \
  "$BUILD/CMP40HXAccelerator.o" \
  -o "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator"

cp "$SRC_DIR/src/Info.plist" "$BUILD/$KEXT_NAME/Contents/Info.plist"

# 兜底: 若编译器没有把 __kmod_info 段带出来, 用 -sectcreate 强制注入(200 字节 kmod_info)
if ! otool -l "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null | grep -q "__kmod_info"; then
  if [ -f "$SRC_DIR/src/kmod_info.bin" ]; then
    echo "-- fallback: 用 -sectcreate 注入 __kmod_info --"
    clang++ -arch x86_64 -mkernel -nostdlib -r -Wl,-kext \
      -Wl,-sectcreate,__DATA,__kmod_info,"$SRC_DIR/src/kmod_info.bin" \
      "$BUILD/CMP40HXAccelerator.o" \
      -o "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator"
  fi
fi

echo "-- ad-hoc sign --"
codesign -f -s - --deep "$BUILD/$KEXT_NAME" 2>/dev/null || \
  echo "WARN: codesign 失败(不影响后续用 OpenCore 注入)"

echo "-- verify --"
file "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator"
echo "-- sections (必须有 __kmod_info) --"
otool -l "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null \
  | grep -E "segname|sectname" | paste - - | sed 's/[[:space:]]\+/ /g'
if otool -l "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null | grep -q "__kmod_info"; then
  echo "OK: __kmod_info 段存在"
else
  echo "FAIL: 缺 __kmod_info 段 (内核不会加载该 kext)"
  exit 4
fi
echo
echo "构建完成: $BUILD/$KEXT_NAME"
echo "SHA256:"
shasum -a 256 "$BUILD/$KEXT_NAME/Contents/MacOS/CMP40HXAccelerator"
