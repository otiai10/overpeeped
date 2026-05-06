# overpeeped — Spec for Claude Code

> 並列に動く Claude Code セッションを「忘れない」ためのデスクトップマスコットアプリ。
> macOS / Ghostty 専用。Swift Package Manager + 純Swift で実装する。
>
> **プロジェクト名の由来**: "peep" はヒナの鳴き声 (ピヨピヨ)。並列に走る Claude Code セッションは育てるべきヒナたちであり、放置するほど鳴き声で存在を主張する。"over-peeped" = ヒナたちに鳴かれすぎている状態 = 無視できない。マスコットは「ヒナ」のメンタルモデルで設計する。

このドキュメントは Claude Code に作業を引き継ぐための仕様書である。Claude Code はこのファイルを読み、Phase 0 の最小スパイクから順に実装を進めること。設計判断に迷ったら「未決定事項」セクションを優先順位の判断基準として使うこと。

---

## 1. 背景と目的

### 解決したい課題
ユーザーは Ghostty で複数の Claude Code セッションを並列に走らせている (worktree ベース)。長時間放置・忘却が頻発し、入力待ちのセッションを見失う。

### 解決アプローチ
**「セッションごとに、デスクトップに浮かぶ小さなマスコット (たまごっち的なヒナ)」** を表示する。各ヒナは状態と経過時間に応じて表情・アニメーション・鳴き声を変え、放置すると怒ったり悲しんだりする。クリックすると、そのセッションが動いている Ghostty ターミナルにフォーカスが当たる。

### 4つの要件
1. **忘れなければいい** → デスクトップに常時ヒナを浮かべる + 鳴き声で主張
2. **待ち状態が発生しているセッションがわかればいい** → 状態に応じた表情変化
3. **representative をクリックしたら Ghostty 上のそのセッションに focus** → AppleScript で focus
4. **representative はマスコットキャラ (放置すると怒る・悲しむ)** → 状態×時間で表情遷移

### スタイル: Windows のカイル君方式
- 各ヒナ = **borderless / 透明背景の独立 NSWindow**
- ウィンドウ枠もタイトルバーもない、キャラの絵だけ浮かぶ
- ドラッグで自由に移動、位置は永続化
- セッションの数だけ表示 (N体並ぶ)

### オプトイン方式 (重要な設計判断)
**ヒナは自動では出現しない。** ユーザーが Claude Code セッション内で `/peep` skill を実行すると、初めてそのセッションが overpeeped に登録される。長く走るタスクや見守ってほしいセッションだけを明示的にヒナ化する設計。これにより:

- どの terminal がどのセッションかを skill 実行時に AppleScript で確実に取得できる (シェルプロンプトのタイトル上書き問題を回避)
- 短時間で終わるセッションが画面を埋め尽くさない
- 「ヒナを孵す」というメタファーとも整合する
- SessionStart hook の session_id stale バグの影響を受けない

---

## 2. 技術スタック

| 層 | 技術 |
|---|---|
| アプリ | Swift 5.9+, SwiftUI + AppKit ハイブリッド |
| ビルド | Swift Package Manager (Xcode プロジェクト不要) |
| 配布 | 自分用、ad-hoc 署名で OK (公証不要) |
| Skill | Claude Code skill (Bash + AppleScript) |
| Hook 連携 | Bash スクリプト → JSON ファイル更新 |
| Ghostty 連携 | AppleScript (osascript 経由) |
| 状態 IPC | ファイル監視 (DispatchSource) |

### 必須環境
- macOS 14+ (Sonoma 以降推奨)
- Ghostty 1.3.0+ (AppleScript API が必要)
- Claude Code (任意の最新版)
- `jq` (Hook と skill の JSON 操作で使用)

---

## 3. アーキテクチャ

```
┌──────────────────────────────────────────────────────────┐
│ Claude Code セッション (Ghostty terminal の中で起動中)    │
│                                                          │
│  ユーザー: 「/peep でこのセッションを見守って」            │
│       ↓                                                  │
│  Claude Code が peep skill を実行                        │
│       ↓                                                  │
│  1. AppleScript で Ghostty terminal UUID を取得         │
│  2. ~/.overpeeped/sessions/<chick_uuid>.json を作成      │
│  3. ~/.overpeeped/index.json に session_id を登録       │
│       ↓                                                  │
│  以降、共通の Hooks (登録済みセッションのみ) で状態更新   │
│   ├ Notification → state="waiting"                       │
│   ├ Stop         → state="done"                          │
│   ├ PreToolUse   → last_activity 更新                    │
│   ├ PostToolUse  → last_activity 更新                    │
│   └ SessionEnd   → state ファイル削除                    │
└──────────────────────────────────────────────────────────┘
                     │ JSON ファイル更新
                     ▼
        ~/.overpeeped/sessions/<chick_uuid>.json
                     │ ファイル監視 (DispatchSource)
                     ▼
┌──────────────────────────────────────────────────────────┐
│ Overpeeped.app (Swift)                                   │
│                                                          │
│  ├ FileWatcher          (DispatchSource で inode 監視)   │
│  ├ SessionStore         (状態を ObservableObject で公開) │
│  ├ ChickWindowManager   (chick ごとに NSWindow 生成)     │
│  ├ ChickView            (SwiftUI: ヒナ描画 + アニメ)      │
│  ├ PeepBubbleView       (鳴き声の吹き出し)               │
│  ├ EmotionEngine        (状態+経過時間 → 感情)           │
│  ├ GhosttyAdapter       (AppleScript ラッパー)           │
│  └ MenuBarController    (NSStatusItem 一覧表示)          │
└──────────────────────────────────────────────────────────┘
```

### 役割分担
| コンポーネント | 責務 |
|---|---|
| **peep skill** | セッションを overpeeped に登録する。terminal UUID 取得・初期 JSON 作成・nickname 管理・stop 処理 |
| **Hooks** | 登録済みセッションの状態を更新するだけ。未登録なら何もしない (no-op) |
| **Swift アプリ** | JSON を監視してヒナを描画、クリック時に Ghostty へフォーカス復帰 |

この分担により、skill が「能動的なオプトイン」、Hooks が「受動的な状態反映」、アプリが「表示」と完全に分離される。

---

## 4. データモデル

### ディレクトリ構造
```
~/.overpeeped/
  ├ sessions/
  │   └ <chick_uuid>.json     # 登録済みセッションごとに 1 ファイル
  ├ index.json                 # session_id → chick_uuid の逆引きインデックス (Hooks 用)
  ├ positions.json             # 各 chick のウィンドウ位置永続化
  └ config.json                # ユーザー設定 (将来拡張)
```

### sessions/<chick_uuid>.json のスキーマ
```json
{
  "chick_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "session_id": "claude-sess-abc123",
  "ghostty_terminal_uuid": "ghostty-term-xyz789",
  "project_name": "triax-hub",
  "nickname": null,
  "cwd": "/Users/hiromu/src/triax/hub",
  "state": "working",
  "started_at": "2026-05-06T10:30:00Z",
  "last_activity_at": "2026-05-06T10:32:15Z",
  "last_state_change_at": "2026-05-06T10:31:45Z"
}
```

### index.json のスキーマ
Hooks が `session_id` から `chick_uuid` を引くための逆引きテーブル。skill が登録時に追加・削除する。

```json
{
  "claude-sess-abc123": "550e8400-e29b-41d4-a716-446655440000",
  "claude-sess-def456": "660f9511-..."
}
```

### state の値
- `working`: PreToolUse / PostToolUse の直後 (動作中)
- `waiting`: Notification hook が発火した直後 (ユーザー入力待ち)
- `done`: Stop hook が発火 (応答完了)

### Ghostty terminal の特定方法
**重要な設計判断**: ターミナルタイトルへのタグ埋め込み (旧案) は、シェルプロンプトがタイトルを上書きするため動作しない。代わりに **`/peep` skill 実行時に AppleScript で `focused terminal` の UUID を直接取得して保存する**。

skill 実行時の AppleScript:
```applescript
tell application "Ghostty"
  set targetTerm to focused terminal of selected tab of front window
  return id of targetTerm
end tell
```

Swift 側からのフォーカス:
```applescript
tell application "Ghostty"
  activate
  set targetTerm to first terminal whose id is "ghostty-term-xyz789"
  focus targetTerm
end tell
```

`/peep` 実行の瞬間、その terminal は確実にフォーカスされている (ユーザーがコマンドをタイプしたばかり) ので、`focused terminal of selected tab of front window` で取得した UUID が正しい terminal を指す。

---

## 5. 感情エンジン仕様

各ヒナは状態と経過時間に応じて感情が変わるだけでなく、**鳴き声 (peep)** で存在を主張する。鳴き声は視覚的な吹き出しテキストとして表示し、音は鳴らさない (静かな環境で使うため)。

`EmotionEngine` は `(state, elapsed_since_last_state_change)` を入力に、現在の感情 (Emotion enum) を返す。鳴き声テキストは Emotion から派生する。

### 状態遷移テーブル
| state | 経過時間 | Emotion | 表情 (例) | アニメーション | Peep (鳴き声) |
|---|---|---|---|---|---|
| working | - | `focused` | 集中顔 | 軽くゆらゆら | (静か) |
| waiting | 0–30s | `expectant` | 期待 (キラキラ目) | 小さくジャンプ | "ぴよ?" |
| waiting | 30s–2min | `impatient` | 不満 (むっ) | 足をパタパタ | "ぴよぴよっ" |
| waiting | 2–5min | `angry` | 怒り (赤くなる) | プルプル震える | "ピヨーッ!" |
| waiting | 5min+ | `sad` | 悲しみ (涙) | しょんぼり | "ぴ...よ..." |
| done | 0–1min | `happy` | 達成感 (✨) | ぴょんぴょん | "ぴよっ♪" |
| done | 1–5min | `lonely` | 寂しい | じっとこちらを見る | "ぴよ..." |
| done | 5min+ | `sulking` | 拗ね (そっぽ) | 後ろ向き | (沈黙) |

### 鳴き声の表示仕様
- ヒナの上に小さな吹き出しを 2〜3秒間隔でフラッシュ表示
- 状態が遷移したタイミングでも鳴く (新しい感情への切り替わりを目立たせる)
- `sulking` と `focused` は鳴かない (集中中は邪魔しない、拗ねたら口もきかない)
- 設定で「鳴き声を表示しない」モードを後の Phase で追加可能

### 経過時間の参照基準
- `working` / `waiting` 中: `last_state_change_at` から
- `done` 中: `last_state_change_at` から (= 完了時刻)

### Emotion enum (Swift)
```swift
enum Emotion: String, CaseIterable {
    case focused, expectant, impatient, angry, sad, happy, lonely, sulking

    var peepText: String? {
        switch self {
        case .focused, .sulking: return nil
        case .expectant: return "ぴよ?"
        case .impatient: return "ぴよぴよっ"
        case .angry:     return "ピヨーッ!"
        case .sad:       return "ぴ...よ..."
        case .happy:     return "ぴよっ♪"
        case .lonely:    return "ぴよ..."
        }
    }
}
```

---

## 6. UI仕様

### ヒナのウィンドウ
- サイズ: **128×128 px** (デフォルト、設定で 64/128/200 切替可)
- スタイル: `.borderless`, `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false`
- ウィンドウレベル: `.floating` (常に最前面、ただしフルスクリーンアプリの邪魔をしない)
- collectionBehavior: `[.canJoinAllSpaces, .stationary, .ignoresCycle]`
- ドラッグ可能 (タイトルバー無しなので `mouseDown` で `window.performDrag(with:)`)
- クリックで Ghostty フォーカス、ドラッグと区別 (移動距離 5px 以下ならクリック扱い)

### ヒナの位置
- 初回出現時: 画面右下から縦に積む (Y方向に 150px 間隔)
- ユーザーがドラッグ移動した位置は `~/.overpeeped/positions.json` に永続化
- `positions.json` のキーは `chick_uuid`

### ホバー時のツールチップ
ヒナの上にマウスを乗せると吹き出し風にプロジェクト名と経過時間を表示:
```
triax-hub (ピー助)
待ち時間: 3分20秒
```
nickname があれば表示する。

### メニューバーアイコン
NSStatusItem に `🐥` 絵文字 (またはアプリ独自アイコン)。クリックでメニュー表示:
- 全 chick の一覧 (絵文字でサマリー: `🥺×2 😡×1`)
- 各 chick 項目: `{nickname または project_name} - {状態}` → クリックで Ghostty フォーカス
- ---
- 「すべて隠す / すべて表示」
- 「設定...」(将来拡張)
- 「終了」

### ヒナの絵 (ドット絵)
- 形式: PNG (透過背景)、各表情ごとに 64×64 px をベースとし 2x (128px) を用意
- アニメーションフレーム: 各 Emotion につき 2〜4 フレーム
- 配置: `Sources/Overpeeped/Resources/sprites/<emotion>_<frame>.png`
- 初期実装では Claude Code がドット絵を生成 (詳細は §11「ドット絵の作り方」)

---

## 7. peep skill 仕様

### skill の配置
```
Sources/Overpeeped/Resources/skill/peep/
  ├ SKILL.md
  └ scripts/
      ├ register.sh    # /peep のメイン処理
      ├ status.sh      # /peep status
      ├ stop.sh        # /peep stop
      └ nickname.sh    # /peep nickname <name>
```

`Scripts/install.sh` がこれらを `~/.claude/skills/peep/` にコピーする。

### サブコマンド
| コマンド | 動作 |
|---|---|
| `/peep` | 現在のセッションを overpeeped に登録 (chick が出現) |
| `/peep status` | 登録済みなら現在の状態と経過時間を表示。未登録なら未登録と表示 |
| `/peep stop` | このセッションの監視を終了 (chick が消える) |
| `/peep nickname <name>` | chick に名前を付ける |

### `/peep` の処理フロー
SKILL.md は Claude Code に対して以下を bash で実行するよう指示する。

1. **既に登録済みかチェック**: `~/.overpeeped/index.json` の `session_id` を見る。存在すれば「既に見守り中です」と返してその chick の情報を表示
2. **Ghostty terminal UUID 取得**:
   ```bash
   GHOSTTY_TERM_UUID=$(osascript -e '
   tell application "Ghostty"
     return id of focused terminal of selected tab of front window
   end tell')
   ```
   失敗したら明確なエラーメッセージ (Ghostty が起動していない / Automation 許可が無い / 1.3.0 未満など)
3. **chick_uuid 生成**: `CHICK_UUID=$(uuidgen)`
4. **JSON 作成**: `~/.overpeeped/sessions/${CHICK_UUID}.json` を atomic に書き込み (tmp + mv)
5. **インデックス更新**: `index.json` に `session_id → chick_uuid` を追加 (これも atomic)
6. **ユーザーへの応答**: 「ぴよっ! 🐥 (project_name) のヒナが孵りました」と返す

skill が受け取る情報:
- `$CLAUDE_PROJECT_DIR`: プロジェクトディレクトリ (cwd の取得に使う)
- 引数 (`/peep nickname <name>` の場合は `<name>` が渡る)
- session_id は skill 実行時の環境変数または引数経由で取得 (Claude Code skill 仕様に従う)

### `/peep stop` の処理フロー
1. `index.json` から `session_id` で `chick_uuid` を引く
2. `sessions/${chick_uuid}.json` と `index.json` の該当エントリを削除
3. 「ぴよ... また呼んでね」と返す

### `/peep nickname <name>` の処理フロー
1. 登録済みかチェック (未登録ならエラー)
2. `sessions/${chick_uuid}.json` の `nickname` フィールドを更新
3. 「ピー助 になりました 🐥」と返す

### atomic 更新のパターン
全てのスクリプトで JSON を更新する際は以下のパターンを使う:
```bash
TMP=$(mktemp)
jq '...' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
```
これにより read-modify-write 中の読み取りで JSON が壊れるのを防ぐ。

---

## 8. Hook 仕様

### 役割
Hooks は **登録済みセッションの状態を更新するだけ**。未登録のセッション (= `index.json` に `session_id` が無い) では即座に `exit 0` で終了する。

### Hook スクリプトの配置
```
~/.overpeeped/hooks/
  ├ notification.sh
  ├ stop.sh
  ├ pre-tool-use.sh
  ├ post-tool-use.sh
  └ session-end.sh
```

**SessionStart hook は使わない** (skill 経由で明示的に登録するため)。

### 共通プロローグ
全 hook は冒頭で以下を実行し、登録済みでなければ早期リターン:
```bash
#!/bin/bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r .session_id)
CHICK_UUID=$(jq -r --arg sid "$SESSION_ID" '.[$sid] // empty' ~/.overpeeped/index.json 2>/dev/null)
if [ -z "$CHICK_UUID" ]; then exit 0; fi
SESSION_FILE="$HOME/.overpeeped/sessions/${CHICK_UUID}.json"
[ -f "$SESSION_FILE" ] || exit 0
```

### settings.json 設定例
```json
{
  "hooks": {
    "Notification": [
      {"hooks": [{"type": "command", "command": "~/.overpeeped/hooks/notification.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "~/.overpeeped/hooks/stop.sh"}]}
    ],
    "PreToolUse": [
      {"hooks": [{"type": "command", "command": "~/.overpeeped/hooks/pre-tool-use.sh"}]}
    ],
    "PostToolUse": [
      {"hooks": [{"type": "command", "command": "~/.overpeeped/hooks/post-tool-use.sh"}]}
    ],
    "SessionEnd": [
      {"hooks": [{"type": "command", "command": "~/.overpeeped/hooks/session-end.sh"}]}
    ]
  }
}
```

### 各 Hook の責務

#### notification.sh
- `state="waiting"`, `last_state_change_at=now` に更新

#### stop.sh
- `state="done"`, `last_state_change_at=now` に更新

#### pre-tool-use.sh / post-tool-use.sh
- `state="working"`, `last_activity_at=now` に更新
- 状態遷移 (例: `waiting` → `working`) が起きる場合は `last_state_change_at` も更新

#### session-end.sh
- `~/.overpeeped/sessions/${CHICK_UUID}.json` を削除
- `~/.overpeeped/index.json` から `session_id` を削除

### Hook 実装上の注意
- **既存 hook を壊さない**: ユーザーは既に `say -v Kyoko` などの hook を運用している。`Scripts/install.sh` が settings.json を更新する際は **マージ形式** (既存配列に append) で行う。jq でマージすること
- **failsafe**: hook の失敗が Claude Code を止めないよう、すべての hook は `exit 0` で終わる (致命エラーでも `exit 0`)
- **atomic 更新**: §7 と同じパターンを使う

---

## 9. Tech Feasibility まとめ

事前調査で確認済みの事項。Claude Code はこれを前提に判断すること。

### ✅ 動く (確証あり)
- Ghostty AppleScript で `focused terminal` の UUID 取得 (1.3.0+)
- AppleScript で UUID から terminal を特定して focus
- borderless / 透明 NSWindow による浮遊ヒナ
- DispatchSource.makeFileSystemObjectSource によるファイル監視
- Claude Code hooks (stdin JSON, 環境変数, 並列実行)
- Claude Code skills (slash command, bash 実行, 引数受け取り)

### ⚠️ 注意点と回避策
- **Ghostty AppleScript API は preview 扱い** (1.4 で破壊的変更の可能性) → AppleScript 操作は `GhosttyAdapter` と skill scripts に隔離。1.4 リリース時は両方を更新するだけで済む構造
- **terminal class に PID/TTY が無い** → skill 経由で登録時に UUID を取得・保存する方式で完全回避
- **シェルプロンプトがターミナルタイトルを上書き** → タイトル方式を使わないので問題にならない
- **SessionStart hook の session_id が再開時に古いまま** → SessionStart hook を使わない設計なので影響なし
- **macOS Automation 許可 (TCC)** が初回プロンプトされる → README に説明、初回は skill 実行時と Swift アプリ起動時の 2 回ダイアログが出る
- **NSWindow クリック vs ドラッグの判定** → 移動距離 5px 以下ならクリック扱い

### ❌ できない / 諦める
- Ghostty 再起動を跨いだ完全復元: terminal UUID は Ghostty 再起動で変わる可能性が高いため、再起動後は chick が「迷子」になる。Phase 5 で「迷子検出 → ユーザーに `/peep` 再実行を促す」機能を入れるかは要検討
- セッション自動検出: skill による明示登録が必要 (これは設計上の選択であり、欠点ではない)

---

## 10. プロジェクト構造

```
overpeeped/
├ Package.swift
├ README.md
├ SPEC.md (このファイル)
├ LESSONS.md (実装中に学んだことを記録)
├ Sources/
│  └ Overpeeped/
│     ├ App.swift                    # @main, NSApplicationDelegate
│     ├ Models/
│     │  ├ SessionState.swift        # JSON スキーマ対応の Codable struct
│     │  └ Emotion.swift             # Emotion enum + transition logic + peepText
│     ├ Engine/
│     │  ├ EmotionEngine.swift       # state + elapsed → Emotion
│     │  ├ FileWatcher.swift         # DispatchSource ラッパー
│     │  └ SessionStore.swift        # ObservableObject, sessions の真実の源
│     ├ Adapters/
│     │  └ GhosttyAdapter.swift      # AppleScript focus by UUID
│     ├ UI/
│     │  ├ ChickWindow.swift         # NSWindow サブクラス (1ヒナ = 1ウィンドウ)
│     │  ├ ChickWindowManager.swift  # セッション数に応じてウィンドウ生成・破棄
│     │  ├ ChickView.swift           # SwiftUI: ヒナ描画 + アニメ
│     │  ├ PeepBubbleView.swift      # 鳴き声の吹き出し
│     │  ├ MenuBarController.swift   # NSStatusItem
│     │  └ TooltipView.swift         # ホバー時の詳細表示
│     ├ Persistence/
│     │  └ PositionStore.swift       # positions.json の読み書き
│     └ Resources/
│        ├ sprites/                  # ドット絵 PNG (ヒナの各表情)
│        └ skill/peep/                # /peep skill 一式
│           ├ SKILL.md
│           └ scripts/
│              ├ register.sh
│              ├ status.sh
│              ├ stop.sh
│              └ nickname.sh
├ Hooks/                              # インストールされる shell スクリプト
│  ├ notification.sh
│  ├ stop.sh
│  ├ pre-tool-use.sh
│  ├ post-tool-use.sh
│  └ session-end.sh
├ Scripts/
│  ├ install.sh                      # ~/.overpeeped/ + ~/.claude/skills/ + settings.json
│  ├ uninstall.sh
│  └ build.sh                        # swift build → .app + ad-hoc 署名
└ Tests/
   └ OverpeepedTests/
      ├ EmotionEngineTests.swift
      └ SessionStateTests.swift
```

### Package.swift の方針
- `executableTarget` を `Overpeeped` として定義
- リソース (sprites/, skill/) を `process` リソースとして埋め込む
- 依存ライブラリは原則ゼロ (純Swift で完結)

### .app バンドル化
`swift build` だけでは `.app` にならないので、`Scripts/build.sh` で:
1. `swift build -c release`
2. `Overpeeped.app/Contents/MacOS/Overpeeped` 配置
3. `Info.plist` 生成 (`LSUIElement = NO`, `NSAppleEventsUsageDescription` を含める)
4. `codesign --force --sign - Overpeeped.app` で ad-hoc 署名

### Scripts/install.sh の責務
1. `~/.overpeeped/{sessions,hooks}` ディレクトリ作成
2. `Hooks/*.sh` を `~/.overpeeped/hooks/` にコピー (実行ビット付与)
3. `Sources/Overpeeped/Resources/skill/peep/` を `~/.claude/skills/peep/` にコピー
4. `~/.claude/settings.json` に hooks エントリをマージ (jq で既存と統合、重複追加しない)
5. `index.json` を空オブジェクトで初期化

---

## 11. ドット絵の作り方 (Claude Code 担当)

ドット絵アセットは Claude Code が SVG → PNG ラスタライズで生成する。

### 仕様
- ベースサイズ: 32×32 px (大きく見せたい場合 64x64 まで)、最終出力は 64×64 と 128×128 の 2 サイズ
- パレット: 8〜16色程度の限定パレット (ドット絵らしさ)
- キャラデザイン: **ヒナ (chick)** をベースとする
  - モチーフ: ぴよぴよしている小鳥のヒナ。丸っこい体、大きな目、小さなくちばし、ふわふわの羽毛感
  - 基本配色: 黄色〜オレンジ系のヒナ色 (Anthropic オレンジとの相性も良い)。状態によって色が変化 (例: angry で頬が赤くなる、sad で青ざめる)
  - シルエットがすぐ「ヒナ」と分かることを優先。リアルな鳥ではなく、デフォルメされたかわいさ重視
  - キャラの細部 (羽の模様、目の形など) は Claude Code が決めてよい (実装後にユーザーが差し替え可能)

### 必要なフレーム
| Emotion | フレーム数 | 動き | デザインメモ |
|---|---|---|---|
| focused | 2 | 軽い上下のゆれ | 目を画面に向けて集中、口を結ぶ |
| expectant | 2 | 小さくジャンプ | 目をキラキラさせて見上げる |
| impatient | 3 | 足踏み | むっとした目、頬が少し膨れる |
| angry | 2 | プルプル震え | 目が吊り上がり、頭の羽毛が逆立つ、頬が赤い |
| sad | 2 | しょんぼりして揺れる | 涙、うつむき、羽が下がる |
| happy | 3 | ぴょんぴょん | 笑顔、羽を広げて喜ぶ、周囲に✨ |
| lonely | 1 | 静止 | じっとこちらを見上げる |
| sulking | 1 | 後ろ向き静止 | 完全にそっぽを向いている |

### 生成方法
1. Claude Code が SVG でドット絵を作る (各セルを `<rect>` で表現)
2. `sips` または ImageMagick で PNG にラスタライズ (アンチエイリアス無効: `-filter point` 等)
3. `Sources/Overpeeped/Resources/sprites/<emotion>_<frame>.png` として配置

### MVP 段階のフォールバック
ドット絵生成が後回しになる場合、初期実装では絵文字 (`🐥` 系) を NSImage 化して表示しても可。Phase 1〜2 はこれで動かしても OK。Phase 4 で本格的なドット絵に置き換える。

---

## 12. マイルストーン (Claude Code への指示)

各 Phase は独立して動作確認が取れる粒度になっている。Phase が終わったら必ず動作確認を行い、次の Phase に進むこと。各 Phase 終了時に `LESSONS.md` に学んだこと・ハマったポイントを追記する。

### Phase 0: Spike — 技術リスク潰し (半日)
**目的**: 「borderless 透明 NSWindow にキャラを乗せて、クリックすると AppleScript で Ghostty terminal を UUID 指定でフォーカスする」というコアループが動くことの確認。

成果物:
- 最小の `swift run` で動く実行ファイル
- 画面に `🐥` が 1個だけ浮かぶ (固定位置、ハードコードされた terminal UUID)
- クリックすると `osascript` でその UUID の terminal にフォーカス
- terminal UUID 取得用のお試しスクリプト `scripts/get-uuid.sh`

検収:
1. `scripts/get-uuid.sh` を Ghostty で実行 → UUID が取れる (TCC ダイアログが出ることも確認)
2. その UUID を `Phase0Demo.swift` のハードコード値に貼り付けて `swift run`
3. 別 terminal にフォーカスがある状態でヒナをクリック → 元の terminal が前面に来る

### Phase 1: peep skill (1日)
**目的**: skill 経由で登録 → JSON ファイルが正しく生成されるところまで完成させる。

成果物:
- `Sources/Overpeeped/Resources/skill/peep/SKILL.md` と `scripts/*.sh`
- `Scripts/install.sh` (skill コピー部分のみ、hooks は Phase 2)
- `~/.overpeeped/` ディレクトリ構造の初期化
- index.json 管理ロジック

検収:
1. `install.sh` 実行 → `~/.claude/skills/peep/` が作成される
2. Ghostty で `claude` 起動 → `/peep` 実行 → 「ぴよっ! 🐥 ... のヒナが孵りました」
3. `cat ~/.overpeeped/sessions/*.json` で正しい JSON が出る (terminal UUID 含む)
4. 同じセッションで再度 `/peep` → 「既に見守り中です」
5. `/peep nickname ピー助` → JSON の nickname が更新される
6. `/peep status` → 現在の状態が表示される
7. `/peep stop` → JSON とインデックスから消える

### Phase 2: 単一 chick MVP (1日)
**目的**: Hooks 統合 + Swift 側で 1体のヒナが状態に応じて表情を変える。

成果物:
- `Hooks/*.sh` (5 種)
- `Scripts/install.sh` 完成版 (hooks マージ含む)
- `FileWatcher` + `SessionStore`
- `EmotionEngine` + テスト
- `ChickView` (Emotion を絵文字または最小ドット絵でレンダリング)
- 1 chick のみ対応 (複数は Phase 3)

検収:
1. install.sh 実行 → settings.json に hooks 追加 (既存設定を破壊しないか確認)
2. `claude` 起動 → `/peep` → ヒナ出現 (focused 顔)
3. 質問入力 → working 顔
4. 応答完了 → happy 顔 (1分後 lonely、5分後 sulking に遷移するか確認)
5. 入力待ちを発生させる (e.g. permission prompt) → expectant → impatient → angry → sad の遷移確認
6. `/peep stop` → ヒナ消える
7. `claude` を `/exit` → SessionEnd hook でヒナ消える

### Phase 3: 複数 chick 対応 (半日)
**目的**: N体のヒナを並べる + クリックで正しい Ghostty terminal に飛ぶ。

成果物:
- `ChickWindowManager` (sessions 数の動的増減)
- `PositionStore` (ドラッグ位置の永続化)
- `GhosttyAdapter` (UUID から terminal を特定して focus)
- ドラッグ移動の実装 (クリックとの区別含む、5px 閾値)

検収:
1. 並列に Claude Code セッション 3つ起動、各セッションで `/peep` → ヒナ 3体出現
2. それぞれ別の状態に遷移させる → 表情が独立して変化
3. 各ヒナをクリック → 対応する Ghostty terminal にフォーカス
4. ドラッグで移動 → アプリ再起動後も位置が維持

### Phase 4: ドット絵 + アニメーション + 鳴き声 (1日)
**目的**: 絵文字を独自ドット絵に置き換え、アニメーション化、鳴き声吹き出し追加。

成果物:
- §11 の全スプライト PNG
- `ChickView` でフレームアニメーション (Timer で 200〜500ms 間隔切替)
- `PeepBubbleView` (鳴き声の吹き出しを 2〜3 秒間隔で表示)
- 状態遷移時のフェードイン/アウト

検収: 各 Emotion でアニメーションが動く、状態切替時に滑らかに遷移する、鳴き声が状態に応じて出る。

### Phase 5: メニューバー + ツールチップ + 仕上げ (半日)
- `MenuBarController` (NSStatusItem)
- `TooltipView` (NSPopover or 独自 NSWindow)
- `Scripts/build.sh` で `.app` バンドル化
- `README.md` (インストール手順 + TCC 許可の説明)
- LaunchAgent で自動起動 (オプション)

検収: メニューバーから全 chick が見える、ホバーで詳細が出る、`.app` がダブルクリックで起動する。

---

## 13. 未決定事項 (デフォルト案つき)

Claude Code が実装中に判断が必要になったら、以下のデフォルトを採用する。ユーザーから別の指示があればそれを優先。

| 論点 | デフォルト | 代案 |
|---|---|---|
| ヒナサイズ | 128×128 px | 64 (小さめ) / 200 (目立つ) |
| 同時表示上限 | 制限なし | 設定で上限を設ける |
| 初期位置 | 画面右下から縦に 150px 間隔 | Ghostty ウィンドウ近く |
| `working` 中の表示 | 表示する (focused 顔) | `waiting` のみ表示 (集中モード) |
| ヒナのキャラデザイン | Claude Code が決める | ユーザー指定 |
| Emotion 遷移閾値 | §5 のテーブル通り | ユーザー設定可能に |
| メニューバーアイコン | 🐥 絵文字 | カスタムアイコン |
| LaunchAgent 自動起動 | 手動起動 | デフォルト ON |
| 同セッションで `/peep` 再実行 | 「既に見守り中」を返す | nickname 変更 UI を出す |
| 複数 Ghostty ウィンドウ時の `front window` | AppleScript の標準動作 (最前面) で OK | 明示的な選択 UI |
| ヒナの鳴き声言語 | 日本語 ("ぴよ" 等) | 英語 ("peep!") に切替可能 |

---

## 14. ユーザーコンテキスト (Claude Code 向け)

実装中、以下の文脈を踏まえると判断が早くなる:

- ユーザーはエンジニア、Go と TypeScript が主、Swift は本格的には初めて
- macOS / Ghostty が日常開発環境
- Claude Code を多用、hooks (`PreToolUse` 等)、subagents、skills の知識あり
- skill の配布は `gh skill` + GitHub プライベートリポジトリで運用している
- 既存 hooks に `say -v Kyoko` を仕込んでいる → 既存設定を破壊しない統合が必須
- アジャイル / Spec-Driven Development が好み、Phase ごとに動作確認しながら進めるのを好む
- TRIAX で Go + Next.js のアプリを GAE で運用、openpyxl で Excel 操作も日常的にやっている
- Lessons Learned / Framework 文書化に慣れている → `LESSONS.md` を Phase ごとに更新するのを推奨

---

## 15. 参考リンク

### Ghostty
- AppleScript API ドキュメント: https://ghostty.org/docs/features/applescript
- 1.3.0 リリースノート: https://ghostty.org/docs/install/release-notes/1-3-0
- terminal class に PID/TTY が無い issue (skill 方式で回避): https://github.com/ghostty-org/ghostty/issues/11592

### Claude Code
- Hooks リファレンス: https://code.claude.com/docs/en/hooks
- Hook 開発スキル: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md
- session_id stale バグ (skill 方式で影響なし): https://github.com/anthropics/claude-code/issues/9188

### macOS / Swift
- NSWindow borderless transparent 実装例: https://gaitatzis.medium.com/create-a-translucent-overlay-window-on-macos-in-swift-67d5e000ce90

### 競合 / 類似ツール (思想の参考)
- manaflow-ai/cmux (Ghostty 対抗ターミナル, サイドバー方式)
- ccmanager (CLI 方式)
- 本プロジェクトはこれらと違い、**ヒナのメタファーで「忘却」を防ぐ** という UX 軸で差別化する

---

## 16. 用語集

実装で混乱しないように用語を固定する。

| 用語 | 意味 | 使う場所 |
|---|---|---|
| **overpeeped** | プロジェクト名・アプリ名 | アプリ全体、リポジトリ名 |
| **chick (ヒナ)** | マスコット 1体。1 登録セッション = 1 chick | ファイル名 (`ChickWindow`, `ChickView` 等)、UI 文言 |
| **peep** | (1) ヒナの鳴き声 / (2) skill 名 (`/peep`) | `peepText`, `PeepBubbleView`, `peep skill` |
| **chick_uuid** | 各 chick の一意 ID。`/peep` 実行時に発行 | 状態ファイルの主キー |
| **session** | Claude Code セッション。chick とは 1:1 対応 | データモデル、`SessionState`, `SessionStore` |
| **登録 (register)** | `/peep` でセッションを overpeeped に紐付ける行為 | skill, ドキュメント |
| **ghostty_terminal_uuid** | Ghostty AppleScript が返す terminal の id | 状態ファイル、`GhosttyAdapter` |

「ペット」「マスコット」「キャラクター」といった一般語は **chick** に統一する。コード上のクラス名・変数名も `Pet*` ではなく `Chick*` を使う。

---

## 17. 実装開始時の最初の一手

Claude Code はこの SPEC を読んだ後、以下の順で着手すること:

1. **README.md のドラフト作成**: ユーザーへの説明・インストール手順 (Phase 0 後に詳細化でよい)
2. **LESSONS.md を空ファイルで作成**: Phase 0 から学びを記録していく
3. **Phase 0 の実装**: AppleScript で terminal UUID を取得するスクリプトと、ハードコード UUID で focus する Swift 最小実装
4. **Phase 0 の動作確認**: 実機で動くこと、TCC ダイアログが出ることを確認
5. **Phase 1 着手**: peep skill の実装

各 Phase の実装に入る前に、その Phase の検収条件を再確認し、テストできる粒度で実装すること。Phase 0 と Phase 1 で AppleScript の挙動を完全に把握できれば、残りは「作るだけ」の作業になる。
