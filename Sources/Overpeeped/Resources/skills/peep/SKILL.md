---
name: peep
description: overpeeped (デスクトップマスコットアプリ) に Claude Code セッションを登録する。`/peep` でセッションをヒナ化 (`/peep <名前>` で命名しつつ登録)、`/peep status` で状態確認、`/peep stop` で監視終了、`/peep nickname <名前>` で命名/改名。並列に走る複数の Claude Code セッションを忘れずに見守りたいときに使う。
allowed-tools: Bash
license: MIT
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
| `<name>` | 登録と同時に名前をつける (予約語 `status` / `stop` / `nickname` / `mission` は除く) |
| `--model <id>` / `-m <id>` | マスコット種を指定して登録 (`<name>` と併用可)。例: `/peep mike --model lizard` / `/peep mike -m=robot` |
| `status` | 登録状態と経過時間を表示 |
| `stop` | このセッションの監視を終了 (マスコットが消える) |
| `nickname <name>` | 既存のマスコットを命名/改名する |
| `mission <text>` | このセッションが掲げるミッション (1 行) を設定 (`mission ""` でクリア) |

`--model` / `-m` に指定できる種: `chick` (既定) / `lizard` / `slime` / `octopus` / `robot` / `ghost`。未知の値は既定の chick として表示される。

dispatcher (`peep.sh`) が `$ARGUMENTS` を見て該当のスクリプトに振り分けます。Claude 側でサブコマンドの解釈や条件分岐は不要です。

## ミッションの自動要約 (登録時 + 節目)

ミッションはマスコットの下に常時ラベルとして表示され、「このヒナが今どんな目的で働いているか」を一目で伝える。これは **Claude (あなた) がセッションの会話から要約して設定する** もので、ユーザーが毎回手で打つものではない。

- **登録 (`/peep` / `/peep <name>` …) が成功したら**、続けて現在の会話から **そのセッションの目的を 1 行 (全角 20〜30 文字程度、体言止め推奨)** に要約し、次を **Bash tool で 1 回** 実行する:

  ```bash
  CLAUDE_SESSION_ID='${CLAUDE_SESSION_ID}' bash '${CLAUDE_SKILL_DIR}/scripts/peep.sh' mission "<要約した1行>"
  ```

  会話がまだ薄くミッションが定まらない場合は、無理に設定せずスキップしてよい (後の節目で設定する)。
- **その後、セッションの焦点が大きく変わったとき** (別 Issue に着手した / 目的が切り替わった等) は、同じコマンドでミッションを更新する。瑣末なステップ単位では更新しない — あくまで「掲げている目的」の粒度。
- ミッション設定/更新コマンドの stdout はユーザーに逐一見せなくてよい (登録本体の応答に対する補助的な動作)。失敗 (exit 非ゼロ) したときだけ簡潔に伝える。
