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
    # それ以外の文字列は nickname つきの新規登録として扱う
    # (予約語 status/stop/nickname は上で吸い取り済み)
    exec bash "$SCRIPT_DIR/register.sh" "$SUBCMD"
    ;;
esac
