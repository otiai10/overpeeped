#!/bin/bash
# user-prompt-submit.sh — Claude Code UserPromptSubmit hook
# overpeeped: state を "thinking" にする (ユーザー入力直後、ツール選定フェーズ)。
# 登録されていないセッションでは何もしない。

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
  if jq --arg now "$NOW" '.state = "thinking" | .last_state_change_at = $now' "$SESSION_FILE" > "$TMP" 2>/dev/null; then
    mv "$TMP" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP"
  else
    rm -f "$TMP"
  fi
fi
exit 0
