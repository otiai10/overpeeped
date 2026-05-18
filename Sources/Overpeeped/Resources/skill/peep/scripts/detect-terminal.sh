#!/bin/bash
# detect-terminal.sh
# 現在の shell が動いている terminal app を判定し、
# その terminal における安定した pane/window ID を取得する。
#
# 標準出力に TAB 区切りで 2 列を出す:
#   <kind>\t<id>
#
# kind は SessionState.TerminalRef.<kind>Kind と一致させる:
#   - "ghostty"
#   - (将来) "iterm2", "terminal_app", "wezterm" 等
#
# 失敗時は exit 1 + stderr に診断ログ。
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# terminal の判別優先順位
#
# 1. $TERM_PROGRAM など環境変数で判別できるもの (確実 & 高速)
# 2. 該当する terminal の AppleScript / 固有 API で pane id を取得
#
# 新しい terminal を足すときの手順:
#   (a) このファイルに detect_<name>() を増やす
#   (b) main の case 文に分岐を追加
#   (c) Swift 側 (TerminalRef.<name>Kind と TerminalAdapter 実装) を増やす
# ─────────────────────────────────────────────────────────────

detect_ghostty() {
  # `/peep` 起動時、その terminal はフォーカスされているので
  # `focused terminal of selected tab of front window` で当該 terminal が取れる。
  local id
  id=$(osascript <<'OSA' 2>&1
tell application "Ghostty"
  return id of focused terminal of selected tab of front window
end tell
OSA
  )
  local status=$?
  if [ "$status" -ne 0 ] || [ -z "$id" ]; then
    cat >&2 <<EOM
Error: Ghostty terminal id の取得に失敗しました。
  - Ghostty 1.3.0+ が起動していますか?
  - Ghostty が前面ウィンドウになっていますか?
  - System Settings → Privacy & Security → Automation で claude (もしくは shell) → Ghostty が許可されていますか?
osascript output: $id
EOM
    return 1
  fi
  printf 'ghostty\t%s\n' "$id"
}

# ─────────────────────────────────────────────────────────────
# main: TERM_PROGRAM で振り分ける
# ─────────────────────────────────────────────────────────────
case "${TERM_PROGRAM:-}" in
  ghostty)
    detect_ghostty
    ;;
  # ─── 新 terminal を足すときはここに case を増やす ───
  # iTerm.app)         detect_iterm2 ;;
  # Apple_Terminal)    detect_terminal_app ;;
  # WezTerm)           detect_wezterm ;;
  *)
    # TERM_PROGRAM が空 / 未知 → Ghostty を試みる (旧版・カスタムビルドで TERM_PROGRAM が
    # 未設定のケースを救う)。失敗したら諦める。
    if detect_ghostty; then
      :
    else
      cat >&2 <<EOM
Error: 対応している terminal を検出できませんでした。
  TERM_PROGRAM='${TERM_PROGRAM:-}'
  対応 terminal: ghostty
EOM
      exit 1
    fi
    ;;
esac
