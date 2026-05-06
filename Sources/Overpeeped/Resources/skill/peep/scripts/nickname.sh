#!/bin/bash
# nickname.sh — /peep nickname <name>
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
NEW_NAME="${1:-}"

if [ -z "$SESSION_ID" ]; then
  echo "Error: CLAUDE_SESSION_ID が未設定です。" >&2
  exit 1
fi
if [ -z "$NEW_NAME" ]; then
  echo "Usage: /peep nickname <name>" >&2
  exit 2
fi

INDEX_FILE="$HOME/.overpeeped/index.json"
SESSIONS_DIR="$HOME/.overpeeped/sessions"

CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null || true)
if [ -z "$CHICK_UUID" ]; then
  echo "未登録です。先に /peep してから命名してください。" >&2
  exit 1
fi

SESSION_FILE="$SESSIONS_DIR/${CHICK_UUID}.json"
if [ ! -f "$SESSION_FILE" ]; then
  echo "Warning: state ファイルが見つかりません ($SESSION_FILE)。" >&2
  exit 1
fi

# nickname 更新 (atomic)
TMP=$(mktemp)
jq --arg name "$NEW_NAME" '.nickname = $name' "$SESSION_FILE" > "$TMP" && mv "$TMP" "$SESSION_FILE"

echo "$NEW_NAME になりました 🐥"
