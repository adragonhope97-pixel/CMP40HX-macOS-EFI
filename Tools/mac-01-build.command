#!/bin/bash
# mac-01-build.command —— Mac 端一键: 检查环境 → 编译 kext → 校验 → 可选复制到 ESP
# 只做构建与复制, 不改 config.plist(那一步单独做, 会先备份)
set +e
cd "$(dirname "$0")" || exit 1
TS="$(date '+%Y%m%d-%H%M%S')"
REPORT="$HOME/Desktop/CMP40HX-BUILD-$TS.txt"

{
echo "===== CMP40HX SKELETON BUILD $TS ====="
echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "目录: $(pwd)"
echo

echo "--- [1] 工具链检查 ---"
if xcode-select -p >/dev/null 2>&1; then
  echo "Xcode CLT: $(xcode-select -p)"
  clang++ --version | head -2
else
  echo "ERROR: 未安装 Xcode Command Line Tools。先运行: xcode-select --install"
  echo "===== ABORT ====="
  exit 1
fi
SDK="$(xcrun --show-sdk-path 2>/dev/null)"
echo "SDK: $SDK"
if [ ! -d "$SDK/System/Library/Frameworks/Kernel.framework/Headers" ]; then
  echo "ERROR: Kernel.framework 头文件缺失, SDK 不完整"
  exit 1
fi
echo

echo "--- [2] 编译 ---"
chmod +x build.sh
./build.sh
BUILD_RC=$?
echo "build.sh exit=$BUILD_RC"
if [ $BUILD_RC -ne 0 ]; then
  echo "===== BUILD FAILED — 把本文件发回分析 ====="
  exit $BUILD_RC
fi
echo

echo "--- [3] 产物校验 ---"
KEXT="build/CMP40HXAccelerator.kext"
ls -la "$KEXT/Contents/MacOS/" "$KEXT/Contents/Info.plist"
echo "架构:"; lipo -info "$KEXT/Contents/MacOS/CMP40HXAccelerator" 2>/dev/null || file "$KEXT/Contents/MacOS/CMP40HXAccelerator"
echo "签名:"; codesign -dv "$KEXT" 2>&1 | head -6
echo "SHA256:"; shasum -a 256 "$KEXT/Contents/MacOS/CMP40HXAccelerator"
echo

echo "--- [4] 现有 EFI 分区 ---"
diskutil list | grep -i -B1 -A1 "EFI" | head -20
echo
echo "下一步(二选一):"
echo "  A) 手动复制: sudo diskutil mount diskXsY && cp -R $KEXT /Volumes/EFI/OC/Kexts/"
echo "  B) 让本脚本复制: 重新运行并加参数  ./mac-01-build.command copy disk0s1"
echo
echo "===== BUILD OK ====="
} > "$REPORT" 2>&1

cat "$REPORT"
echo
echo "报告: $REPORT"

# 可选: 复制到 ESP
if [ "${1:-}" = "copy" ] && [ -n "${2:-}" ]; then
  echo
  echo "--- 挂载 $2 并复制 ---"
  sudo diskutil mount "$2" || { echo "挂载失败, 检查 diskutil list 的标识符"; exit 1; }
  if [ ! -d /Volumes/EFI/OC/Kexts ]; then
    echo "ERROR: /Volumes/EFI/OC/Kexts 不存在 — 这个分区可能不是 OpenCore 的 ESP"
    exit 1
  fi
  cp -R "build/CMP40HXAccelerator.kext" /Volumes/EFI/OC/Kexts/
  ls -la /Volumes/EFI/OC/Kexts/ | tail -5
  echo "已复制。现在可以回 Windows 侧改 config.plist(会先备份),或在此手动加 Kernel>Add 条目。"
fi

read -r -p "按 Enter 退出..."
