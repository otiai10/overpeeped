#!/bin/bash
# register.sh — /peep [<nickname>]
# 現在の Claude Code セッションを overpeeped に登録する。
# 第1引数があれば nickname として同時に設定する。
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
NICKNAME_ARG="${1:-}"
if [ -z "$SESSION_ID" ]; then
  echo "Error: CLAUDE_SESSION_ID が未設定です (skill 経由で呼ばれていない可能性)。" >&2
  exit 1
fi

OVERPEEPED_DIR="$HOME/.overpeeped"
SESSIONS_DIR="$OVERPEEPED_DIR/sessions"
INDEX_FILE="$OVERPEEPED_DIR/index.json"

mkdir -p "$SESSIONS_DIR"
[ -f "$INDEX_FILE" ] || echo "{}" > "$INDEX_FILE"

# ─────────────────────────────────────────────────────────────
# 1. 既に登録済みかチェック
# ─────────────────────────────────────────────────────────────
EXISTING=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' "$INDEX_FILE" 2>/dev/null || true)
if [ -n "$EXISTING" ]; then
  EXISTING_FILE="$SESSIONS_DIR/${EXISTING}.json"
  if [ -f "$EXISTING_FILE" ]; then
    NICKNAME=$(jq -r '.nickname // ""' "$EXISTING_FILE")
    PROJECT=$(jq -r '.project_name // ""' "$EXISTING_FILE")
    if [ -n "$NICKNAME" ] && [ "$NICKNAME" != "null" ]; then
      echo "ぴよっ! 🐥 既に見守り中です ($NICKNAME / $PROJECT)"
    else
      echo "ぴよっ! 🐥 既に見守り中です ($PROJECT)"
    fi
    exit 0
  fi
  # index に残っているが state ファイルが無い → 自己修復のため index から消して新規登録に進む
  TMP=$(mktemp)
  jq --arg sid "$SESSION_ID" 'del(.[$sid])' "$INDEX_FILE" > "$TMP" && mv "$TMP" "$INDEX_FILE"
fi

# ─────────────────────────────────────────────────────────────
# 2. 現在の terminal を判別し、その pane/window id を取得
# ─────────────────────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DETECT_OUT=$("$SCRIPT_DIR/detect-terminal.sh") || {
  echo "Error: terminal の検出に失敗しました (detect-terminal.sh 参照)。" >&2
  exit 1
}
TERMINAL_KIND="${DETECT_OUT%$'\t'*}"
TERMINAL_ID="${DETECT_OUT#*$'\t'}"
if [ -z "$TERMINAL_KIND" ] || [ -z "$TERMINAL_ID" ] || [ "$TERMINAL_KIND" = "$TERMINAL_ID" ]; then
  echo "Error: detect-terminal.sh の出力が不正です: '$DETECT_OUT'" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 3. chick_uuid 生成 + メタデータ収集
# ─────────────────────────────────────────────────────────────
CHICK_UUID=$(uuidgen)
CWD="$(pwd)"
PROJECT_NAME="${CWD##*/}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# nickname は引数があればそれを使い、無ければ null のまま
if [ -n "$NICKNAME_ARG" ]; then
  NICKNAME_JQ_VAL="$NICKNAME_ARG"
else
  NICKNAME_JQ_VAL=""
fi

# ─────────────────────────────────────────────────────────────
# 4. session ファイルを atomic に作成
# ─────────────────────────────────────────────────────────────
SESSION_FILE="$SESSIONS_DIR/${CHICK_UUID}.json"
TMP=$(mktemp)
jq -n \
  --arg chick_uuid "$CHICK_UUID" \
  --arg session_id "$SESSION_ID" \
  --arg terminal_kind "$TERMINAL_KIND" \
  --arg terminal_id "$TERMINAL_ID" \
  --arg project_name "$PROJECT_NAME" \
  --arg nickname "$NICKNAME_JQ_VAL" \
  --arg cwd "$CWD" \
  --arg now "$NOW" \
  '{
    chick_uuid: $chick_uuid,
    agent: {
      kind: "claude_code",
      session_id: $session_id
    },
    terminal: {
      kind: $terminal_kind,
      id: $terminal_id
    },
    project_name: $project_name,
    nickname: (if $nickname == "" then null else $nickname end),
    cwd: $cwd,
    state: "working",
    started_at: $now,
    last_activity_at: $now,
    last_state_change_at: $now
  }' > "$TMP"
mv "$TMP" "$SESSION_FILE"

# ─────────────────────────────────────────────────────────────
# 5. index.json を atomic に更新
# ─────────────────────────────────────────────────────────────
TMP=$(mktemp)
jq --arg sid "$SESSION_ID" --arg cuid "$CHICK_UUID" \
  '. + {($sid): $cuid}' "$INDEX_FILE" > "$TMP"
mv "$TMP" "$INDEX_FILE"

# ─────────────────────────────────────────────────────────────
# 6. ユーザーへの応答
# ─────────────────────────────────────────────────────────────
if [ -n "$NICKNAME_ARG" ]; then
  echo "ぴよっ! 🐥 ($NICKNAME_ARG / $PROJECT_NAME) のヒナが孵りました"
else
  echo "ぴよっ! 🐥 ($PROJECT_NAME) のヒナが孵りました"
fi
