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
| (なし) | 現在のセッションを overpeeped に登録 (マスコットが出現) |
| `<name>` | 登録と同時に名前をつける (予約語 `status` / `stop` / `nickname` は除く) |
| `--model <id>` | マスコット種を指定して登録 (`<name>` と併用可)。例: `/peep mike --model lizard` |
| `status` | 登録状態と経過時間を表示 |
| `stop` | このセッションの監視を終了 (マスコットが消える) |
| `nickname <name>` | 既存のマスコットを命名/改名する |

`--model` に指定できる種: `chick` (既定) / `lizard`。未知の値は既定の chick として表示される。

dispatcher (`peep.sh`) が `$ARGUMENTS` を見て該当のスクリプトに振り分けます。Claude 側でサブコマンドの解釈や条件分岐は不要です。
