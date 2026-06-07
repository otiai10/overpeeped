#!/bin/bash
# mission.sh — /peep mission <text>
# このセッションが掲げるミッション (1 行要約) を state ファイルに書き込む。
# 空文字を渡すとミッションをクリアする (/peep mission "")。
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
MISSION="${1:-}"

if [ -z "$SESSION_ID" ]; then
  echo "Error: CLAUDE_SESSION_ID が未設定です。" >&2
  exit 1
fi

INDEX_FILE="$HOME/.overpeeped/index.json"
SESSIONS_DIR="$HOME/.overpeeped/sessions"

MASCOT_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null || true)
if [ -z "$MASCOT_UUID" ]; then
  echo "未登録です。先に /peep してからミッションを設定してください。" >&2
  exit 1
fi

SESSION_FILE="$SESSIONS_DIR/${MASCOT_UUID}.json"
if [ ! -f "$SESSION_FILE" ]; then
  echo "Warning: state ファイルが見つかりません ($SESSION_FILE)。" >&2
  exit 1
fi

# mission 更新 (atomic)。空文字は null にしてクリア。
TMP=$(mktemp)
jq --arg m "$MISSION" '.mission = (if $m == "" then null else $m end)' "$SESSION_FILE" > "$TMP" && mv "$TMP" "$SESSION_FILE"

if [ -z "$MISSION" ]; then
  echo "ミッションをクリアしました 🐥"
else
  echo "🎯 ミッション設定: $MISSION"
fi
