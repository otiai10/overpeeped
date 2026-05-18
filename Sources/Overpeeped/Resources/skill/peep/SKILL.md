---
name: peep
description: overpeeped (デスクトップマスコットアプリ) に Claude Code セッションを登録する。`/peep` でセッションをヒナ化 (`/peep <名前>` で命名しつつ登録)、`/peep status` で状態確認、`/peep stop` で監視終了、`/peep nickname <名前>` で命名/改名。並列に走る複数の Claude Code セッションを忘れずに見守りたいときに使う。
allowed-tools: Bash
---

# /peep — overpeeped にセッションを登録する

ユーザーが `/peep` slash command を実行しました。引数: `$ARGUMENTS`

## やること

下記のコマンドを **Bash tool で 1 回だけ** 実行してください。

```bash
CLAUDE_SESSION_ID='${CLAUDE_SESSION_ID}' bash '${CLAUDE_SKILL_DIR}/scripts/peep.sh' $ARGUMENTS
```

## 出力

スクリプトの **stdout を、そのまま** ユーザーに返答として表示してください (装飾不要、追加説明不要)。

スクリプトが exit code 非ゼロを返した場合は、stderr の内容も併せてユーザーに見せ、原因を判断できるようにしてください。

## サブコマンド一覧 (参考)

| 引数 | 動作 |
|---|---|
| (なし) | 現在のセッションを overpeeped に登録 (ヒナが孵る) |
| `<name>` | ヒナを孵すと同時に名前をつける (予約語 `status` / `stop` / `nickname` は除く) |
| `status` | 登録状態と経過時間を表示 |
| `stop` | このセッションの監視を終了 (ヒナが消える) |
| `nickname <name>` | 既存のヒナを命名/改名する |

dispatcher (`peep.sh`) が `$ARGUMENTS` を見て該当のスクリプトに振り分けます。Claude 側でサブコマンドの解釈や条件分岐は不要です。
