#!/bin/bash
# peep.sh — /peep slash command の dispatcher
#
# UserPromptExpansion hook / SKILL.md から呼ばれる。$1 をサブコマンドとみなし
# 対応スクリプトに exec する。
# CLAUDE_SESSION_ID は環境変数で渡すか、先頭の --session-id=<id> で指定する
# (hook 外から model が実行するとき用。env prefix だと permission rule の
# prefix match に載らないため option 形式を用意している)。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${1:-}" in
  --session-id=*)
    export CLAUDE_SESSION_ID="${1#--session-id=}"
    shift
    ;;
  --session-id)
    export CLAUDE_SESSION_ID="${2:-}"
    shift 2 || shift
    ;;
esac

SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  ""|--model|--model=*|-m|-m=*)
    # 引数なし、または先頭が --model / -m … (nickname 無しで種だけ指定)
    exec bash "$SCRIPT_DIR/register.sh" "$SUBCMD" "$@"
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
  mission)
    exec bash "$SCRIPT_DIR/mission.sh" "$@"
    ;;
  *)
    # それ以外の文字列は nickname つきの新規登録として扱う。
    # 残りの引数 ("$@") はそのまま渡す (--model <id> 等)。
    # (予約語 status/stop/nickname/mission は上で吸い取り済み)
    exec bash "$SCRIPT_DIR/register.sh" "$SUBCMD" "$@"
    ;;
esac
