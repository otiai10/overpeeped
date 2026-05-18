#!/bin/bash
# pre-tool-use.sh — Claude Code PreToolUse hook
# overpeeped: ツール実行を捕捉して state を更新する。
#   - AskUserQuestion / ExitPlanMode は user の入力を待つので state="asking"
#     ("asking" は既存の許可待ちと同じ emotion 系列に乗り、黄→橙→赤と熱を上げる)
#   - それ以外は通常通り state="working"
# state 遷移時だけ last_state_change_at を更新し、同じ state なら last_activity_at のみ。

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
INDEX_FILE="$HOME/.overpeeped/index.json"
SESSION_FILE=""

if [ -n "$SESSION_ID" ] && [ -f "$INDEX_FILE" ]; then
  CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null)
  if [ -n "$CHICK_UUID" ]; then
    CANDIDATE="$HOME/.overpeeped/sessions/${CHICK_UUID}.json"
    [ -f "$CANDIDATE" ] && SESSION_FILE="$CANDIDATE"
  fi
fi

# user-blocking なツールかを判定。codex 等他 agent の同等ツールを将来追加する場合はここに足す。
case "$TOOL_NAME" in
  AskUserQuestion|ExitPlanMode) STATE="asking" ;;
  *)                            STATE="working" ;;
esac

if [ -n "$SESSION_FILE" ]; then
  NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TMP=$(mktemp)
  if jq --arg now "$NOW" --arg state "$STATE" '
    if .state != $state then
      .state = $state | .last_state_change_at = $now | .last_activity_at = $now
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
