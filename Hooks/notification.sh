#!/bin/bash
# notification.sh — Claude Code Notification hook
# overpeeped: state を "waiting" にして last_state_change_at を更新する。
# 登録されていないセッションでは何もしない (no-op + exit 0)。
# failsafe: 致命エラーでも exit 0 で claude を止めない。

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
INDEX_FILE="$HOME/.overpeeped/index.json"
SESSION_FILE=""

if [ -n "$SESSION_ID" ] && [ -f "$INDEX_FILE" ]; then
  CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null)
  if [ -n "$CHICK_UUID" ]; then
    CANDIDATE="$HOME/.overpeeped/sessions/${CHICK_UUID}.json"
    [ -f "$CANDIDATE" ] && SESSION_FILE="$CANDIDATE"
  fi
fi

if [ -n "$SESSION_FILE" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP=$(mktemp)
  if jq --arg now "$NOW" '.state = "waiting" | .last_state_change_at = $now' "$SESSION_FILE" > "$TMP" 2>/dev/null; then
    mv "$TMP" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP"
  else
    rm -f "$TMP"
  fi
fi
exit 0
