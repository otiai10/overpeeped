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
APP_BUNDLE_SRC="$REPO_DIR/Overpeeped.app"
APP_BUNDLE_DST="$HOME/Applications/Overpeeped.app"
CLI_DST="$HOME/.local/bin/overpeeped"

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

merge_hook "Notification"     "$HOOKS_DST/notification.sh"
merge_hook "Stop"             "$HOOKS_DST/stop.sh"
merge_hook "PreToolUse"       "$HOOKS_DST/pre-tool-use.sh"
merge_hook "PostToolUse"      "$HOOKS_DST/post-tool-use.sh"
merge_hook "SessionEnd"       "$HOOKS_DST/session-end.sh"
merge_hook "UserPromptSubmit" "$HOOKS_DST/user-prompt-submit.sh"

# ─────────────────────────────────────────────────────────────
# 5. Overpeeped.app を ~/Applications/ にコピー (無ければ build.sh を呼ぶ)
# ─────────────────────────────────────────────────────────────
echo "==> Overpeeped.app: $APP_BUNDLE_DST"
if [ ! -d "$APP_BUNDLE_SRC" ]; then
  echo "  Overpeeped.app が無いのでビルドします (Scripts/build.sh)"
  bash "$SCRIPT_DIR/build.sh"
fi

mkdir -p "$(dirname "$APP_BUNDLE_DST")"
rm -rf "$APP_BUNDLE_DST"
cp -R "$APP_BUNDLE_SRC" "$APP_BUNDLE_DST"
echo "  copied $APP_BUNDLE_SRC → $APP_BUNDLE_DST"

# ─────────────────────────────────────────────────────────────
# 6. CLI ランチャー ~/.local/bin/overpeeped
#    `overpeeped` でアプリを起動できるようにする (open -a 経由)
# ─────────────────────────────────────────────────────────────
echo "==> CLI launcher: $CLI_DST"
mkdir -p "$(dirname "$CLI_DST")"
cat > "$CLI_DST" <<'CLI'
#!/bin/bash
# overpeeped CLI launcher — Overpeeped.app をフォアグラウンド起動する薄いラッパ
exec open -a Overpeeped "$@"
CLI
chmod +x "$CLI_DST"

# PATH チェック
PATH_HINT=""
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH_HINT="yes" ;;
esac

echo ""
echo "✨ overpeeped installed."
echo ""
echo "  GUI 起動    : open -a Overpeeped     (or Spotlight で 'Overpeeped')"
echo "  CLI 起動    : overpeeped"
echo "  Claude セッション内: /peep / /peep status / /peep stop / /peep nickname <名前>"
echo ""
if [ -n "$PATH_HINT" ]; then
  echo "⚠  ~/.local/bin が PATH にありません。次のいずれかを ~/.zshrc に追加してください:"
  echo '     export PATH="$HOME/.local/bin:$PATH"'
  echo ""
fi
echo "既存 settings.json は $BACKUP にバックアップ済み (壊れたら戻せます)"
