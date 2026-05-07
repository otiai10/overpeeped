#!/bin/bash
# test-emotion.sh — 開発時に各 emotion を即座に確認するためのテストツール
#
# 使い方:
#   bash Scripts/test-emotion.sh <emotion>
#
# emotion:
#   working / focused      state=working
#   expectant              state=waiting (last_state_change_at = now)
#   impatient              state=waiting (last_state_change_at = now - 60s)
#   angry                  state=waiting (last_state_change_at = now - 180s)
#   sad                    state=waiting (last_state_change_at = now - 360s)
#   happy                  state=done    (last_state_change_at = now)
#   lonely                 state=done    (last_state_change_at = now - 120s)
#   sulking                state=done    (last_state_change_at = now - 360s)
#
# 全ての登録 chick に同じ状態を適用する (テスト目的)。
set -euo pipefail

EMOTION="${1:-}"
if [ -z "$EMOTION" ]; then
  echo "Usage: bash Scripts/test-emotion.sh <emotion>" >&2
  echo "  emotion: thinking | focused | asking | expectant | impatient | angry | sad | happy | lonely | sulking" >&2
  exit 2
fi

case "$EMOTION" in
  thinking)        STATE="thinking"; OFFSET_SEC=0 ;;
  working|focused) STATE="working";  OFFSET_SEC=0 ;;
  asking)          STATE="asking";   OFFSET_SEC=0 ;;     # permission_request
  expectant)       STATE="idle";     OFFSET_SEC=0 ;;
  impatient)       STATE="idle";     OFFSET_SEC=60 ;;    # > 30s
  angry)           STATE="idle";     OFFSET_SEC=180 ;;   # > 120s
  sad)             STATE="idle";     OFFSET_SEC=360 ;;   # > 300s
  happy)           STATE="done";     OFFSET_SEC=0 ;;
  lonely)          STATE="done";     OFFSET_SEC=120 ;;   # > 60s
  sulking)         STATE="done";     OFFSET_SEC=360 ;;   # > 300s
  *)
    echo "Unknown emotion: $EMOTION" >&2
    exit 2
    ;;
esac

# 過去時刻を計算 (BSD date)
TS=$(date -u -v-${OFFSET_SEC}S +%Y-%m-%dT%H:%M:%SZ)

SESSIONS_DIR="$HOME/.overpeeped/sessions"
shopt -s nullglob
FILES=("$SESSIONS_DIR"/*.json)
if [ ${#FILES[@]} -eq 0 ]; then
  echo "No registered chicks. Run /peep in a Claude Code session first." >&2
  exit 1
fi

for f in "${FILES[@]}"; do
  TMP=$(mktemp)
  jq --arg state "$STATE" --arg ts "$TS" \
    '.state = $state | .last_state_change_at = $ts | .last_activity_at = $ts' \
    "$f" > "$TMP" && mv "$TMP" "$f"
  CUUID=$(basename "$f" .json | cut -c1-8)
  echo "[$EMOTION] $CUUID: state=$STATE last_state_change_at=$TS"
done

echo ""
echo "swift run の Overpeeped がファイル監視で反映するはずです (1〜2 秒)"
