#!/bin/bash
# user-prompt-expansion.sh — Claude Code UserPromptExpansion hook
# overpeeped: `/peep <args>` を skill 展開の前に横取りし、peep.sh を直接実行して
# `decision: block` で完結させる。model turn を一切消費しない (/rename 等の
# built-in local command と同等の体感になる)。
#
# 入力 (stdin JSON): session_id / expansion_type / command_name / command_args / prompt
# 出力 (stdout JSON): {"decision": "block", "reason": "<peep.sh の出力>"}
#
# /peep 以外の command では何も出力せず exit 0 (素通し)。
# jq や peep.sh が見つからない環境でも素通しし、従来の SKILL.md 経路に任せる。

INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0

COMMAND_NAME=$(echo "$INPUT" | jq -r '.command_name // empty' 2>/dev/null)
[ "$COMMAND_NAME" = "peep" ] || exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
COMMAND_ARGS=$(echo "$INPUT" | jq -r '.command_args // ""' 2>/dev/null)

PEEP_SH="$HOME/.claude/skills/peep/scripts/peep.sh"
[ -f "$PEEP_SH" ] || exit 0

# ─────────────────────────────────────────────────────────────
# command_args (生文字列) を引数列に分解する。
# mission だけはサブコマンド以降の全体を 1 引数として渡す (空白を含むため)。
# それ以外 (register / status / stop / nickname) は空白区切りで十分
# — SKILL.md 経路の `peep.sh $ARGUMENTS` と同じ分解粒度。
# ─────────────────────────────────────────────────────────────
ARGS=()
case "$COMMAND_ARGS" in
  "")
    ;;
  mission)
    ARGS=(mission)
    ;;
  mission\ *)
    REST="${COMMAND_ARGS#mission }"
    # ユーザーが引用符で囲んだ場合は 1 層だけ剥がす (/peep mission "資料の生成" 等)
    case "$REST" in
      '"'*'"') REST="${REST#\"}"; REST="${REST%\"}" ;;
      "'"*"'") REST="${REST#?}"; REST="${REST%?}" ;;
    esac
    ARGS=(mission "$REST")
    ;;
  *)
    read -r -a ARGS <<< "$COMMAND_ARGS"
    ;;
esac

OUT=$(CLAUDE_SESSION_ID="$SESSION_ID" bash "$PEEP_SH" "${ARGS[@]}" 2>&1)
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  OUT="⚠ /peep の実行に失敗しました (exit $STATUS)
$OUT"
fi

# 展開を block して peep.sh の出力をユーザーに見せる。skill は load されない。
jq -n --arg reason "$OUT" '{decision: "block", reason: $reason}'
exit 0
