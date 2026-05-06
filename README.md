# overpeeped 🐥

> 並列に走る Claude Code セッションを「忘れない」ためのデスクトップマスコットアプリ。

ユーザーが Ghostty で複数の [Claude Code](https://claude.com/claude-code) セッションを並列に走らせていると、入力待ちのセッションを見失いがち。
**overpeeped** は、見守って欲しいセッションごとに小さなヒナ (chick) をデスクトップに浮かべる。
ヒナは状態と経過時間に応じて表情と鳴き声を変え、放置すると怒ったり悲しんだりする。
クリックすると、そのセッションが動いている Ghostty terminal にフォーカスが戻る。

> **peep** = ヒナの鳴き声 (ピヨピヨ)。並列に走る Claude Code セッションは育てるべきヒナたちであり、放置するほど鳴き声で存在を主張する。
> **over-peeped** = ヒナたちに鳴かれすぎている状態 = 無視できない。

## 必須環境

- macOS 14+ (Sonoma 以降推奨)
- [Ghostty](https://ghostty.org) 1.3.0+
- [Claude Code](https://claude.com/claude-code)
- `jq`

## インストール

```sh
git clone https://github.com/otiai10/overpeeped.git
cd overpeeped
./Scripts/build.sh        # Overpeeped.app を生成 (ad-hoc 署名)
./Scripts/install.sh      # ~/.overpeeped/ + ~/.claude/skills/peep/ + hooks をインストール
open Overpeeped.app
```

> ⚠️ 初回起動時に macOS から **Automation 許可** (System Settings → Privacy & Security → Automation) を求められる。Ghostty への AppleScript 操作のため必須。

## 使い方

Claude Code セッションの中で:

```
/peep                     # 現在のセッションを overpeeped に登録 (ヒナが孵る)
/peep nickname ピー助     # ヒナに名前をつける
/peep status              # 現在の状態と経過時間を表示
/peep stop                # 監視を終了 (ヒナが消える)
```

ヒナの状態と感情:

| 状態 | 経過時間 | 感情 | 鳴き声 |
|---|---|---|---|
| working | - | 集中 | (静か) |
| waiting | 0–30s | 期待 | ぴよ? |
| waiting | 30s–2min | 不満 | ぴよぴよっ |
| waiting | 2–5min | 怒り | ピヨーッ! |
| waiting | 5min+ | 悲しみ | ぴ...よ... |
| done | 0–1min | 達成感 | ぴよっ♪ |
| done | 1–5min | 寂しい | ぴよ... |
| done | 5min+ | 拗ね | (沈黙) |

ヒナをクリック → 対応する Ghostty terminal が前面に出る。
ヒナをドラッグ → 自由に移動 (位置は永続化)。

## 設計

詳細仕様は [`knowledge/decisions/SPEC.md`](./knowledge/decisions/SPEC.md) を参照。
実装中に踏んだ罠と知見は [`knowledge/decisions/LESSONS.md`](./knowledge/decisions/LESSONS.md) にある。

- **オプトイン方式**: `/peep` を実行したセッションだけがヒナ化される
- **責務分離**: skill (登録) / Hooks (状態反映) / Swift アプリ (表示) が完全に独立
- **既存 hooks 非破壊**: `~/.claude/settings.json` の hooks は jq でマージ統合する

## ライセンス

MIT
