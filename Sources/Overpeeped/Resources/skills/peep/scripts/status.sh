#!/bin/bash
# status.sh — /peep status
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
INDEX_FILE="$HOME/.overpeeped/index.json"
SESSIONS_DIR="$HOME/.overpeeped/sessions"

if [ -z "$SESSION_ID" ]; then
  echo "Error: CLAUDE_SESSION_ID が未設定です。" >&2
  exit 1
fi
if [ ! -f "$INDEX_FILE" ]; then
  echo "未登録のセッションです。/peep で見守りを開始してください。"
  exit 0
fi

MASCOT_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null || true)
if [ -z "$MASCOT_UUID" ]; then
  echo "未登録のセッションです。/peep で見守りを開始してください。"
  exit 0
fi

SESSION_FILE="$SESSIONS_DIR/${MASCOT_UUID}.json"
if [ ! -f "$SESSION_FILE" ]; then
  echo "Warning: index には登録されていますが state ファイルが見つかりません ($SESSION_FILE)。" >&2
  exit 1
fi

NICKNAME=$(jq -r '.nickname // ""' "$SESSION_FILE")
PROJECT=$(jq -r '.project_name' "$SESSION_FILE")
STATE=$(jq -r '.state' "$SESSION_FILE")
LAST_CHANGE=$(jq -r '.last_state_change_at' "$SESSION_FILE")
LAST_ACT=$(jq -r '.last_activity_at' "$SESSION_FILE")

# 経過秒数 (macOS の BSD date)
LAST_CHANGE_EPOCH=$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$LAST_CHANGE" +%s 2>/dev/null || echo 0)
NOW_EPOCH=$(date -u +%s)
ELAPSED=$((NOW_EPOCH - LAST_CHANGE_EPOCH))

# 経過時間を「N 分 N 秒」形式に
if [ "$ELAPSED" -ge 60 ]; then
  MIN=$((ELAPSED / 60))
  SEC=$((ELAPSED % 60))
  ELAPSED_HUMAN="${MIN}分${SEC}秒"
else
  ELAPSED_HUMAN="${ELAPSED}秒"
fi

NAME_DISPLAY="$PROJECT"
if [ -n "$NICKNAME" ] && [ "$NICKNAME" != "null" ]; then
  NAME_DISPLAY="$NICKNAME ($PROJECT)"
fi

MISSION=$(jq -r '.mission // ""' "$SESSION_FILE")

cat <<EOM
🐥 $NAME_DISPLAY
  状態: $STATE
  最終遷移からの経過: $ELAPSED_HUMAN
  最終アクティビティ: $LAST_ACT
EOM
if [ -n "$MISSION" ] && [ "$MISSION" != "null" ]; then
  echo "  🎯 ミッション: $MISSION"
fi
