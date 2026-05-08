# overpeeped 🐥

> 並列に走る Claude Code セッションを「忘れない」ためのデスクトップマスコットアプリ。

ユーザーが Ghostty で複数の [Claude Code](https://claude.com/claude-code) セッションを並列に走らせていると、入力待ちのセッションを見失いがち。
**overpeeped** は、見守って欲しいセッションごとに小さなヒナ (chick) をデスクトップに浮かべる。
ヒナは状態と経過時間に応じて表情と色を変え、放置されすぎると最終的に**焼き鳥 🍗** になる。
クリックすると、そのセッションが動いている Ghostty terminal の tab/pane にフォーカスが戻る。

> **peep** = ヒナの鳴き声 (ピヨピヨ)。並列に走る Claude Code セッションは育てるべきヒナたちであり、放置するほど鳴き声で存在を主張する。
> **over-peeped** = ヒナたちに鳴かれすぎている状態 = 無視できない。

## 必須環境

- macOS 14+ (Sonoma 以降)
- [Ghostty](https://ghostty.org) 1.3.0+
- [Claude Code](https://claude.com/claude-code)
- `jq`

## インストール

```sh
git clone git@github.com:otiai10/overpeeped.git
cd overpeeped
./Scripts/build.sh        # Overpeeped.app を生成 (ad-hoc 署名)
./Scripts/install.sh      # 全部入り: skill / hooks / .app / CLI launcher
```

`install.sh` がやること:

| 配置先 | 内容 |
|---|---|
| `~/.overpeeped/sessions/`, `~/.overpeeped/hooks/` | session 状態の保存場所と hook スクリプト |
| `~/.claude/skills/peep/` | `/peep` slash command |
| `~/.claude/settings.json` | hooks エントリを **jq でマージ** (既存設定は破壊しない、自動バックアップ付き) |
| `~/Applications/Overpeeped.app` | アプリ本体 |
| `~/.local/bin/overpeeped` | CLI ランチャ (`open -a Overpeeped` を呼ぶ薄いラッパ) |

## 起動方法

```sh
overpeeped              # CLI から (~/.local/bin が PATH にあれば)
open -a Overpeeped      # macOS 標準
# Spotlight (⌘Space) で "Overpeeped" と入力しても起動可
```

起動するとメニューバー右上に🐥アイコンが常駐し、Dock には出ません (LSUIElement)。

> ⚠️ 初回起動時、macOS が **Automation 許可** ダイアログを出します (Ghostty への AppleScript 操作のため必須)。
> 後から System Settings → Privacy & Security → Automation で確認/変更できます。

## 使い方

Claude Code セッションの中で:

```
/peep                     # このセッションを overpeeped に登録 (ヒナが孵る)
/peep nickname ピー助      # ヒナに名前をつける
/peep status              # 現在の状態と経過時間を表示
/peep stop                # 監視を終了 (ヒナが消える)
```

ヒナの **5 段階の状態**:

| state | hook trigger | ヒナの様子 | balloon |
|---|---|---|---|
| **thinking** | `UserPromptSubmit` | ゆっくり右へ歩く (普通の黄) | **💭** 常時表示 |
| **working** | `Pre/PostToolUse` | テキパキ右へ歩く | なし |
| **asking** | `Notification` (permission 系) | 経過時間で熱量UP | "ぴよ?"〜"ピヨーッ!"〜"ぴ...よ..." |
| **idle** | `Notification` (その他) | 同上 | 同上 |
| **done** | `Stop` | ✨ → 🥺 → 🙄 | "ぴよっ♪" 等 |

待たされ続けると体色も変わる (asking/idle):

| 経過 | Emotion | 体色 |
|---|---|---|
| 0–30s | expectant | flashy gold (鮮やか黄) |
| 30s–2min | impatient | medium amber (橙) |
| 2–5min | angry | red (真っ赤) |
| **5min+** | sad | **🍗 丸焼きチキン** |

操作:
- ヒナを **クリック** → 対応する Ghostty tab/pane にフォーカス
- ヒナを **ドラッグ** → 自由に移動 (位置は `~/.overpeeped/positions.json` に永続化)
- ヒナの上にマウスオーバー → ポインタカーソル + ホバー詳細
- terminal が消えた chick は **グレー化 + ラベルに `?`** を付与 (orphan 検出)

メニューバーの🐥アイコン → drop down:
- 全 chick の一覧 (クリックで Ghostty へ飛ぶ)
- ヒナを隠す/表示 (⌘H)
- Overpeeped を終了 (⌘Q)

## 開発

```sh
swift run                                 # 開発中の起動 (Ctrl-C で停止)
swift test                                # ユニットテスト
bash Scripts/test-emotion.sh angry        # ヒナを 真っ赤に強制遷移 (デバッグ用)
bash Scripts/test-emotion.sh sad          # 🍗 丸焼きに
bash Scripts/test-emotion.sh focused      # 元に戻す
```

## 設計

詳細仕様は [`knowledge/decisions/SPEC.md`](./knowledge/decisions/SPEC.md)。
実装中に踏んだ罠は [`knowledge/decisions/LESSONS.md`](./knowledge/decisions/LESSONS.md)。

- **オプトイン方式**: `/peep` を実行したセッションだけがヒナ化される
- **責務分離**: skill (登録) / Hooks (状態反映) / Swift アプリ (表示) が完全に独立
- **既存 hooks 非破壊**: `~/.claude/settings.json` は `jq` でマージ統合する

## ライセンス

MIT
