#!/bin/bash
# notification.sh — Claude Code Notification hook
# overpeeped: 通知の内容で state を分岐:
#   - permission 系 (title/message に "permission" 含む) → state="asking"
#   - その他 (idle 通知含む)                              → state="idle"
# 登録されていないセッションでは何もしない (no-op + exit 0)。
# failsafe: 致命エラーでも exit 0 で claude を止めない。

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
  TITLE=$(echo "$INPUT" | jq -r '.title // ""' 2>/dev/null)
  MSG=$(echo "$INPUT"   | jq -r '.message // ""' 2>/dev/null)
  REASON=$(echo "$INPUT" | jq -r '.reason // ""' 2>/dev/null)

  # permission 関連かを推定 (Claude Code の Notification は形式に揺れがあるので
  # title/message/reason のいずれかに "permission" / "permit" / "approval" を含むかでヒューリスティック判定)
  if echo "$TITLE $MSG $REASON" | grep -qiE 'permission|permit|approval|approve'; then
    STATE="asking"
  else
    STATE="idle"
  fi

  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP=$(mktemp)
  if jq --arg now "$NOW" --arg state "$STATE" --arg reason "$REASON" \
       '.state = $state | .last_state_change_at = $now | .notification_reason = $reason' \
       "$SESSION_FILE" > "$TMP" 2>/dev/null; then
    mv "$TMP" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP"
  else
    rm -f "$TMP"
  fi
fi
exit 0
