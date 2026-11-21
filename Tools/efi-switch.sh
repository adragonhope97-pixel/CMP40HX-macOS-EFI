#!/bin/bash
# ============================================================
# efi-switch.sh — OpenCore 多方案配置切换器（通用版）
#
# 用途：在一个目录里维护多份 config.plist（如 baseline / plan-a / plan-b），
#       用本脚本在它们之间安全切换，每步都有校验与快照。
#
# 用法：
#   ./efi-switch.sh list                列出全部方案
#   ./efi-switch.sh status              按 SHA256 识别当前部署的是哪个方案
#   ./efi-switch.sh switch <name>       切换（校验 → 快照 → 部署 → 复核）
#   ./efi-switch.sh rollback            回滚到最近一次快照
#   ./efi-switch.sh backup-efi          整包备份当前 EFI（时间戳命名）
#   ./efi-switch.sh validate            用 ocvalidate 校验当前部署的 config
#
# 环境变量（都可选）：
#   PLANS_DIR    方案目录，默认 <repo>/Integration/config-plans
#   EFI_CONFIG   目标 config，默认 /g/EFI/OC/config.plist（Windows Git Bash 下 G 盘）
#   BACKUP_DIR   备份目录，默认 <repo>/Integration
#   OCVALIDATE   ocvalidate 可执行文件路径；找不到则跳过格式校验并提示
#
# 安全设计：不覆盖唯一备份；切换前强制校验 + 快照；切换后复核 SHA256。
# ============================================================
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CMP40HX_ROOT:-$(cd "$HERE/.." && pwd)}"
PLANS="${PLANS_DIR:-$ROOT/Integration/config-plans}"
EFI_CFG="${EFI_CONFIG:-/g/EFI/OC/config.plist}"
BK="${BACKUP_DIR:-$ROOT/Integration}"
OCVAL="${OCVALIDATE:-$(command -v ocvalidate 2>/dev/null || true)}"
TS="$(date '+%Y%m%d-%H%M%S')"

die() { echo "ERROR: $*" >&2; exit 1; }
sha() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

need_plans() {
  [ -d "$PLANS" ] || die "方案目录不存在: $PLANS（用 PLANS_DIR 指定）"
  compgen -G "$PLANS/*.plist" >/dev/null || die "方案目录里没有 *.plist: $PLANS"
}

cmd_list() {
  need_plans
  echo "方案目录: $PLANS"
  for f in "$PLANS"/*.plist; do
    printf '  %-46s %s\n' "$(basename "$f")" "$(sha "$f" | cut -c1-16)"
  done
}

cmd_status() {
  [ -f "$EFI_CFG" ] || die "目标 config 不存在: $EFI_CFG"
  local cur; cur="$(sha "$EFI_CFG")"
  echo "当前部署: $EFI_CFG"
  echo "  SHA256: $cur"
  if [ -d "$PLANS" ]; then
    local hit=""
    for f in "$PLANS"/*.plist; do
      [ "$(sha "$f")" = "$cur" ] && hit="$(basename "$f")"
    done
    if [ -n "$hit" ]; then echo "  识别结果: $hit"; else echo "  识别结果: 未匹配任何已保存方案"; fi
  fi
}

cmd_validate() {
  [ -f "$EFI_CFG" ] || die "目标 config 不存在: $EFI_CFG"
  if [ -z "$OCVAL" ] || [ ! -x "$OCVAL" ]; then
    echo "SKIP: 未找到 ocvalidate（用 OCVALIDATE=路径 指定）"
    plutil -lint "$EFI_CFG" 2>/dev/null || python3 -c "import plistlib,sys; plistlib.load(open(sys.argv[1],'rb')); print('plist OK')" "$EFI_CFG"
    return
  fi
  "$OCVAL" "$EFI_CFG"
}

cmd_switch() {
  local name="${1:-}"; [ -n "$name" ] || die "用法: switch <方案名或文件名>"
  need_plans
  local target="$PLANS/$name"
  [ -f "$target" ] || target="$PLANS/$name.plist"
  [ -f "$target" ] || die "找不到方案: $name"

  echo "== [1/4] 校验目标方案 =="
  if [ -n "$OCVAL" ] && [ -x "$OCVAL" ]; then "$OCVAL" "$target" || die "目标方案校验失败"; else
    python3 -c "import plistlib,sys; plistlib.load(open(sys.argv[1],'rb')); print('plist OK')" "$target" || die "目标方案不是合法 plist"
  fi

  echo "== [2/4] 快照当前 config =="
  if [ -f "$EFI_CFG" ]; then
    mkdir -p "$BK"
    local snap="$BK/config-backup-$TS.plist"
    cp "$EFI_CFG" "$snap" || die "快照失败，中止（不动原文件）"
    echo "  快照: $snap"
  else
    echo "  目标尚不存在，跳过快照"
  fi

  echo "== [3/4] 部署 =="
  cp "$target" "$EFI_CFG" || die "写入失败"

  echo "== [4/4] 复核 =="
  cmd_status
}

cmd_rollback() {
  mkdir -p "$BK"
  local latest; latest="$(ls -1t "$BK"/config-backup-*.plist 2>/dev/null | head -1)"
  [ -n "$latest" ] || die "没有可用快照（$BK/config-backup-*.plist）"
  echo "使用快照: $latest"
  cp "$EFI_CFG" "$BK/config-before-rollback-$TS.plist" 2>/dev/null || true
  cp "$latest" "$EFI_CFG" || die "回滚写入失败"
  cmd_validate
  cmd_status
}

cmd_backup_efi() {
  local efidir; efidir="$(dirname "$(dirname "$EFI_CFG")")"
  [ -d "$efidir" ] || die "EFI 目录不存在: $efidir"
  mkdir -p "$BK"
  local out="$BK/EFI-backup-$TS.tar.gz"
  [ -e "$out" ] && die "备份已存在，拒绝覆盖: $out"
  tar -czf "$out" -C "$(dirname "$efidir")" "$(basename "$efidir")" || die "备份失败"
  echo "已创建: $out ($(du -h "$out" | cut -f1))"
  echo "既有备份未触碰。"
}

case "${1:-}" in
  list)       cmd_list ;;
  status)     cmd_status ;;
  switch)     shift; cmd_switch "$@" ;;
  rollback)   cmd_rollback ;;
  backup-efi) cmd_backup_efi ;;
  validate)   cmd_validate ;;
  *) sed -n '2,26p' "$0"; exit 1 ;;
esac
