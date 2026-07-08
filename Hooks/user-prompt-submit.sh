#!/bin/bash
# user-prompt-submit.sh — Claude Code UserPromptSubmit hook
# overpeeped: state を "thinking" にする (ユーザー入力直後、ツール選定フェーズ)。
# 登録されていないセッションでは何もしない。
#
# 加えて、登録済みでミッション未設定のセッションには一度だけ stdout で
# 「会話からミッションを要約して設定せよ」という指示を context として注入する
# (UserPromptSubmit は exit 0 の stdout が model への context になる)。
# /peep の登録が UserPromptExpansion hook で完結し model を経由しなくなったため、
# ミッションの自動要約はこの nudge が次の通常ターンに便乗して行う。

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

  # ─────────────────────────────────────────────────────────────
  # ミッション nudge (一度だけ)
  # ─────────────────────────────────────────────────────────────
  MISSION=$(jq -r '.mission // ""' "$SESSION_FILE" 2>/dev/null)
  NUDGED=$(jq -r '.mission_nudged // false' "$SESSION_FILE" 2>/dev/null)
  if [ -z "$MISSION" ] && [ "$NUDGED" != "true" ]; then
    TMP=$(mktemp)
    if jq '.mission_nudged = true' "$SESSION_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$SESSION_FILE" 2>/dev/null || rm -f "$TMP"
    else
      rm -f "$TMP"
    fi
    PEEP_SH="$HOME/.claude/skills/peep/scripts/peep.sh"
    cat <<EOM
[overpeeped] このセッションはデスクトップマスコット overpeeped に登録済みですが、ミッション (マスコットの下に常時表示される 1 行ラベル) が未設定です。現在のタスクに取りかかるついでに、会話からこのセッションの目的を 1 行 (全角 20〜30 文字程度、体言止め推奨) に要約し、次を Bash tool で 1 回実行してください:

  bash "$PEEP_SH" --session-id='$SESSION_ID' mission "<要約した 1 行>"

この操作はユーザーへの逐一報告不要です (失敗したときだけ簡潔に伝える)。以後、セッションの目的が大きく変わったときも同じコマンドでミッションを更新してください。会話がまだ薄く目的が定まらない場合は、何もせず本来のタスクに専念して構いません。
EOM
  fi
fi
exit 0
