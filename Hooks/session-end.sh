#!/bin/bash
# session-end.sh — Claude Code SessionEnd hook
# overpeeped: 登録セッションのファイルと index エントリを削除する。

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
INDEX_FILE="$HOME/.overpeeped/index.json"

if [ -n "$SESSION_ID" ] && [ -f "$INDEX_FILE" ]; then
  CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null)
  if [ -n "$CHICK_UUID" ]; then
    rm -f "$HOME/.overpeeped/sessions/${CHICK_UUID}.json"
    TMP=$(mktemp)
    if jq --arg sid "$SESSION_ID" 'del(.[$sid])' "$INDEX_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$INDEX_FILE" 2>/dev/null || rm -f "$TMP"
    else
      rm -f "$TMP"
    fi
  fi
fi
exit 0
