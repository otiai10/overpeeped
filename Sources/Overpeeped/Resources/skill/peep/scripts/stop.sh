#!/bin/bash
# stop.sh — /peep stop
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
INDEX_FILE="$HOME/.overpeeped/index.json"
SESSIONS_DIR="$HOME/.overpeeped/sessions"

if [ -z "$SESSION_ID" ]; then
  echo "Error: CLAUDE_SESSION_ID が未設定です。" >&2
  exit 1
fi
if [ ! -f "$INDEX_FILE" ]; then
  echo "ぴよ? 元から見守っていません。"
  exit 0
fi

CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null || true)
if [ -z "$CHICK_UUID" ]; then
  echo "ぴよ? 元から見守っていません。"
  exit 0
fi

# session ファイル削除
rm -f "$SESSIONS_DIR/${CHICK_UUID}.json"

# index から削除 (atomic)
TMP=$(mktemp)
jq --arg sid "$SESSION_ID" 'del(.[$sid])' "$INDEX_FILE" > "$TMP" && mv "$TMP" "$INDEX_FILE"

echo "ぴよ... また呼んでね"
