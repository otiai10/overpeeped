#!/bin/bash
# Phase 0 のお試しスクリプト
# 現在フォーカスされている Ghostty terminal の UUID を取得して標準出力に出す
#
# 使い方:
#   Ghostty で `bash scripts/get-uuid.sh` を実行する
#   → そのウィンドウ・タブの terminal id が出力される
#
# 初回実行時、macOS が Automation 許可ダイアログを出す
# (System Settings → Privacy & Security → Automation で確認可能)

set -euo pipefail

UUID=$(osascript <<'OSASCRIPT' 2>&1
tell application "Ghostty"
  set targetTerm to focused terminal of selected tab of front window
  return id of targetTerm
end tell
OSASCRIPT
)

# osascript の戻り値で AppleScript エラーを区別する
if [ $? -ne 0 ]; then
  echo "Error: AppleScript failed. Is Ghostty 1.3.0+ running and Automation allowed?" >&2
  echo "Detail: $UUID" >&2
  exit 1
fi

echo "$UUID"
