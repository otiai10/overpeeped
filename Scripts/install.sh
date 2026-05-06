#!/bin/bash
# install.sh — overpeeped のインストーラ
#
# Phase 1: peep skill を ~/.claude/skills/peep/ にコピー
# Phase 2: hooks を ~/.overpeeped/hooks/ にコピー + ~/.claude/settings.json に hooks エントリをマージ
#
# 既存の settings.json は jq でマージ統合する (重複追加しない、既存 hook を破壊しない)。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_SRC="$REPO_DIR/Sources/Overpeeped/Resources/skill/peep"
HOOKS_SRC="$REPO_DIR/Hooks"
SKILL_DST="$HOME/.claude/skills/peep"
OVERPEEPED_DIR="$HOME/.overpeeped"
HOOKS_DST="$OVERPEEPED_DIR/hooks"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq が見つかりません。'brew install jq' でインストールしてください。" >&2
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# 1. ~/.overpeeped/ 初期化
# ─────────────────────────────────────────────────────────────
echo "==> ~/.overpeeped/ 初期化"
mkdir -p "$OVERPEEPED_DIR/sessions"
mkdir -p "$HOOKS_DST"
if [ ! -f "$OVERPEEPED_DIR/index.json" ]; then
  echo "{}" > "$OVERPEEPED_DIR/index.json"
  echo "  created index.json"
else
  echo "  index.json already exists (kept as-is)"
fi

# ─────────────────────────────────────────────────────────────
# 2. peep skill インストール
# ─────────────────────────────────────────────────────────────
echo "==> peep skill インストール: $SKILL_DST"
mkdir -p "$SKILL_DST/scripts"
cp "$SKILL_SRC/SKILL.md" "$SKILL_DST/SKILL.md"
cp "$SKILL_SRC/scripts/"*.sh "$SKILL_DST/scripts/"
chmod +x "$SKILL_DST/scripts/"*.sh

# ─────────────────────────────────────────────────────────────
# 3. Hooks インストール
# ─────────────────────────────────────────────────────────────
echo "==> hooks インストール: $HOOKS_DST"
cp "$HOOKS_SRC/"*.sh "$HOOKS_DST/"
chmod +x "$HOOKS_DST/"*.sh

# ─────────────────────────────────────────────────────────────
# 4. ~/.claude/settings.json をマージ
#    既存の hooks 配列に append。同じ command が既にあるなら追加しない (idempotent)
# ─────────────────────────────────────────────────────────────
echo "==> settings.json マージ: $CLAUDE_SETTINGS"
mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
if [ ! -f "$CLAUDE_SETTINGS" ]; then
  echo "{}" > "$CLAUDE_SETTINGS"
  echo "  created (was missing)"
fi

# 既存 settings.json をバックアップ (タイムスタンプ付き)
BACKUP="${CLAUDE_SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CLAUDE_SETTINGS" "$BACKUP"
echo "  backup: $BACKUP"

merge_hook() {
  local event="$1"      # 例: Notification
  local script="$2"     # 例: $HOOKS_DST/notification.sh

  local TMP
  TMP=$(mktemp)
  jq --arg event "$event" --arg cmd "$script" '
    .hooks //= {} |
    .hooks[$event] //= [] |
    # 既に同じ command があればスキップ
    if (.hooks[$event] | map(.hooks[]?.command // empty) | any(. == $cmd)) then
      .
    else
      .hooks[$event] += [{
        "hooks": [
          {"type": "command", "command": $cmd}
        ]
      }]
    end
  ' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
}

merge_hook "Notification" "$HOOKS_DST/notification.sh"
merge_hook "Stop"         "$HOOKS_DST/stop.sh"
merge_hook "PreToolUse"   "$HOOKS_DST/pre-tool-use.sh"
merge_hook "PostToolUse"  "$HOOKS_DST/post-tool-use.sh"
merge_hook "SessionEnd"   "$HOOKS_DST/session-end.sh"

echo ""
echo "✨ overpeeped (Phase 2) installed."
echo ""
echo "次のステップ:"
echo "  1. swift build -c release  (もしくは swift run)"
echo "  2. Ghostty で claude を起動"
echo "  3. /peep を実行 → 画面右下に🐥が浮かぶ"
echo "  4. 質問入力で working、応答完了で done(happy→lonely→sulking) を観察"
echo "  5. /peep stop でヒナ消滅、/exit で SessionEnd hook により消滅"
echo ""
echo "既存 settings.json は $BACKUP にバックアップ済み (壊れたら戻せます)"
