#!/bin/bash
# register.sh — /peep
# 現在の Claude Code セッションを overpeeped に登録する。
set -euo pipefail

SESSION_ID="${CLAUDE_SESSION_ID:-}"
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
# 2. Ghostty terminal UUID を AppleScript で取得
# ─────────────────────────────────────────────────────────────
# `/peep` を打った瞬間その terminal はフォーカスされているので
# `focused terminal of selected tab of front window` が確実に当該 terminal を指す。
GHOSTTY_TERM_UUID=$(osascript <<'OSA' 2>&1
tell application "Ghostty"
  return id of focused terminal of selected tab of front window
end tell
OSA
)
OSA_STATUS=$?
if [ "$OSA_STATUS" -ne 0 ] || [ -z "$GHOSTTY_TERM_UUID" ]; then
  cat >&2 <<EOM
Error: Ghostty terminal UUID の取得に失敗しました。
  - Ghostty 1.3.0+ が起動していますか?
  - Ghostty が前面ウィンドウになっていますか?
  - System Settings → Privacy & Security → Automation で claude (もしくは shell) → Ghostty が許可されていますか?
osascript output: $GHOSTTY_TERM_UUID
EOM
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 3. chick_uuid 生成 + メタデータ収集
# ─────────────────────────────────────────────────────────────
CHICK_UUID=$(uuidgen)
CWD="$(pwd)"
PROJECT_NAME="${CWD##*/}"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ─────────────────────────────────────────────────────────────
# 4. session ファイルを atomic に作成
# ─────────────────────────────────────────────────────────────
SESSION_FILE="$SESSIONS_DIR/${CHICK_UUID}.json"
TMP=$(mktemp)
jq -n \
  --arg chick_uuid "$CHICK_UUID" \
  --arg session_id "$SESSION_ID" \
  --arg ghostty_term "$GHOSTTY_TERM_UUID" \
  --arg project_name "$PROJECT_NAME" \
  --arg cwd "$CWD" \
  --arg now "$NOW" \
  '{
    chick_uuid: $chick_uuid,
    session_id: $session_id,
    ghostty_terminal_uuid: $ghostty_term,
    project_name: $project_name,
    nickname: null,
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
echo "ぴよっ! 🐥 ($PROJECT_NAME) のヒナが孵りました"
