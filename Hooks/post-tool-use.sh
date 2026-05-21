#!/bin/bash
# post-tool-use.sh — Claude Code PostToolUse hook
# overpeeped: state を "working" にして last_activity_at を更新する。
# 直前の state が "working" でなかった場合は last_state_change_at も更新する。

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
INDEX_FILE="$HOME/.overpeeped/index.json"
SESSION_FILE=""

if [ -n "$SESSION_ID" ] && [ -f "$INDEX_FILE" ]; then
  MASCOT_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null)
  if [ -n "$MASCOT_UUID" ]; then
    CANDIDATE="$HOME/.overpeeped/sessions/${MASCOT_UUID}.json"
    [ -f "$CANDIDATE" ] && SESSION_FILE="$CANDIDATE"
  fi
fi

if [ -n "$SESSION_FILE" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP=$(mktemp)
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
