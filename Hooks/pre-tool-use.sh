#!/bin/bash
# pre-tool-use.sh — Claude Code PreToolUse hook
# overpeeped: state を "working" にして last_activity_at を更新する。
# 直前の state が "working" でなかった場合は last_state_change_at も更新する。

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
  # state 遷移時のみ last_state_change_at を更新する
  if jq --arg now "$NOW" '
    if .state != "working" then
      .state = "working" | .last_state_change_at = $now | .last_activity_at = $now
    else
      .last_activity_at = $now
    end
  ' "$SESSION_FILE" > "$TMP" 2>/dev/null; then
    mv "$TMP" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP"
  else
    rm -f "$TMP"
  fi
fi
exit 0
