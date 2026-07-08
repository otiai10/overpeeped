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
SKILL_SRC="$REPO_DIR/Sources/Overpeeped/Resources/skills/peep"
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

# matcher 付き版。UserPromptExpansion の matcher は command_name にマッチする。
merge_matcher_hook() {
  local event="$1"      # 例: UserPromptExpansion
  local matcher="$2"    # 例: peep
  local script="$3"

  local TMP
  TMP=$(mktemp)
  jq --arg event "$event" --arg matcher "$matcher" --arg cmd "$script" '
    .hooks //= {} |
    .hooks[$event] //= [] |
    if (.hooks[$event] | map(.hooks[]?.command // empty) | any(. == $cmd)) then
      .
    else
      .hooks[$event] += [{
        "matcher": $matcher,
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
# /peep を skill 展開前に横取りして model turn なしで完結させる (要 Claude Code 2.1.204+)
merge_matcher_hook "UserPromptExpansion" "peep" "$HOOKS_DST/user-prompt-expansion.sh"

# ミッション自動要約 (user-prompt-submit.sh の nudge を受けて model が実行する
# `bash ~/.claude/skills/peep/scripts/peep.sh --session-id=… mission "…"`) が
# permission prompt で会話を止めないよう、この 1 コマンドだけ allowlist に足す。
PEEP_ALLOW_RULE="Bash(bash $SKILL_DST/scripts/peep.sh:*)"
TMP=$(mktemp)
jq --arg rule "$PEEP_ALLOW_RULE" '
  .permissions //= {} |
  .permissions.allow //= [] |
  if (.permissions.allow | index($rule)) then . else .permissions.allow += [$rule] end
' "$CLAUDE_SETTINGS" > "$TMP" && mv "$TMP" "$CLAUDE_SETTINGS"
echo "  permissions.allow: $PEEP_ALLOW_RULE"

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
#    `overpeeped`            → アプリ起動 (open -a 経由)
#    `overpeeped --quit|-q`  → 起動中アプリを graceful 終了 (アプリ本体に委譲)
# ─────────────────────────────────────────────────────────────
echo "==> CLI launcher: $CLI_DST"
mkdir -p "$(dirname "$CLI_DST")"
cat > "$CLI_DST" <<'CLI'
#!/bin/bash
# overpeeped CLI launcher
#   overpeeped            — Overpeeped.app を起動
#   overpeeped --quit|-q  — 起動中の Overpeeped を graceful に終了 (幽霊チックを掃除して停止)
APP="$HOME/Applications/Overpeeped.app"
case "${1:-}" in
  -q|--quit)
    exec "$APP/Contents/MacOS/Overpeeped" --quit
    ;;
  *)
    exec open -a Overpeeped "$@"
    ;;
esac
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
echo "  CLI 終了    : overpeeped --quit      (-q も可)"
echo "  Claude セッション内: /peep [<名前>] / /peep status / /peep stop / /peep nickname <名前>"
echo ""
if [ -n "$PATH_HINT" ]; then
  echo "⚠  ~/.local/bin が PATH にありません。次のいずれかを ~/.zshrc に追加してください:"
  echo '     export PATH="$HOME/.local/bin:$PATH"'
  echo ""
fi
echo "既存 settings.json は $BACKUP にバックアップ済み (壊れたら戻せます)"
