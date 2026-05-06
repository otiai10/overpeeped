#!/bin/bash
# peep.sh — /peep slash command の dispatcher
#
# SKILL.md から呼ばれる。$1 をサブコマンドとみなし対応スクリプトに exec する。
# CLAUDE_SESSION_ID は環境変数で渡される前提。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  "")
    exec bash "$SCRIPT_DIR/register.sh"
    ;;
  status)
    exec bash "$SCRIPT_DIR/status.sh"
    ;;
  stop)
    exec bash "$SCRIPT_DIR/stop.sh"
    ;;
  nickname)
    exec bash "$SCRIPT_DIR/nickname.sh" "$@"
    ;;
  *)
    cat >&2 <<EOM
Unknown /peep subcommand: $SUBCMD

Usage:
  /peep                       現在のセッションをヒナ化
  /peep status                状態確認
  /peep stop                  監視終了
  /peep nickname <name>       ヒナに名前をつける
EOM
    exit 2
    ;;
esac
