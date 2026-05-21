# LESSONS

実装中に学んだこと・ハマったポイントを Phase ごとに記録する。

<!-- Phase ごとに append する。新しい Phase は下に追加。 -->

## Phase 0

### Ghostty AppleScript の階層構造
`application > windows > tabs > terminals` のネスト。`first terminal whose id is X` をトップレベルで書いても引けない (`-1719 / no such object`)。階層をそのまま `repeat with w in windows / repeat with t in tabs of w / repeat with term in terminals of t` でループする必要がある。SPEC §4 のサンプルはそのままでは動かないので注意。

### `focus terminal` だけでは tab は切り替わらない
公式ドキュメント (https://ghostty.org/docs/features/applescript) より:
- `focus` は **pane (terminal) を選択 + その window を前面に持ってくる** だけ
- **tab 選択は別** で、`select tab tThatTab` を明示的に呼ぶ必要がある

正しい順序:
```applescript
select tab t  -- tab を切り替える
focus term    -- pane 選択 + window 前面化
```

### NSWindow を画面右下に置くときの座標
`visibleFrame` は左下原点、`setFrameOrigin` はウィンドウの左下隅を指定する。右下に置くには `(maxX - width - margin, minY + margin)`。`maxY - 160` のような書き方をすると右上に出る (= 最初のミス)。

### Ghostty terminal 識別子の選択肢 (Ghostty 1.3.1 時点)
- **AppleScript の `id of terminal`** (大文字 UUID): Ghostty プロセス生存中は一意。skill から `osascript` で取得可能。overpeeped はこれを採用 (SPEC §4)
- env では公開されていない: `GHOSTTY_*` は全シェルで共通でペインごとに変わらない
- 代替案 ① TTY (`ps -o tty= -p $$`) と login PID (PPID チェーンの comm=`login`): セッション中は一意だが ペイン close で再利用される。永続キー不可
- 代替案 ② `.zshrc` で `export GHOSTTY_PANE_ID=${GHOSTTY_PANE_ID:-$(uuidgen)}`: 子プロセスに env 継承されるので claude にも伝わる。AppleScript 不要のフォールバックとして覚えておく
- 注意: AppleScript の id は **Ghostty 再起動で変わる** (= SPEC §9 で受容済み、Phase 5 で迷子検出検討)

## Phase 1

### Claude Code skill の string substitution
SKILL.md は **LLM への指示文** であり、Bash tool 経由で間接実行される (= 直接 bash として実行されない)。
SKILL.md 内では以下が **LLM が読む前にレンダリング時置換される**:
- `${CLAUDE_SESSION_ID}` — 現セッションの ID (hooks に来る `session_id` と同一)
- `${CLAUDE_SKILL_DIR}` — `~/.claude/skills/<name>/` の絶対パス
- `${CLAUDE_PROJECT_DIR}` — プロジェクトルート
- `$ARGUMENTS`, `$0`, `$1`, ... — slash command 引数

skill から bash に session_id を渡す canonical な方法:
```bash
CLAUDE_SESSION_ID='${CLAUDE_SESSION_ID}' bash '${CLAUDE_SKILL_DIR}/scripts/<dispatcher>.sh' $ARGUMENTS
```
(SKILL.md の中にこう書くと、LLM が見るのは展開後の値)

### dispatcher (peep.sh) を 1 本かます設計
SPEC §7 では `register.sh` `status.sh` `stop.sh` `nickname.sh` の 4 ファイル構成。
`/peep <subcommand>` の振り分けを LLM の判断に委ねるとブレが出るので、
**`peep.sh` という dispatcher** を追加し、SKILL.md は dispatcher 1 本だけを呼ぶ形にした。
LLM はサブコマンド解釈をしない = 出力を**そのまま** ユーザーに返すだけ、と SKILL.md に明示。

### macOS BSD date での ISO8601 → epoch
Linux の GNU date と違い `-d` が無い。BSD date は:
```bash
date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ISO" +%s
```
status.sh の経過秒計算で使用。

### atomic 更新パターン
全 .sh で JSON を更新するときは `mktemp` → `jq > $TMP` → `mv $TMP $FILE`。
read-modify-write 中の半端な書き込みでファイル監視側 (Phase 2 以降) が壊れた JSON を読まないようにする。

### 動作確認は SKILL を経由しなくてもできる
`CLAUDE_SESSION_ID=test-001 bash ~/.claude/skills/peep/scripts/peep.sh [args]` で bash 単体テスト可能。
Claude Code セッション越しに `/peep` を打つ前にロジック品質を担保できるので便利。

## Phase 2

### Hook の failsafe パターン
`set -e` を使うとどこかでコマンドが失敗した瞬間にスクリプトが終了し、Claude Code 側は exit code 非ゼロを受け取って警告を出す可能性がある。SPEC §8 に従い、**hooks は全て exit 0 で終わる**べきなので:
- `set -e` を使わず明示的な if 文で制御
- `mv` も `|| rm -f "$TMP"` で握り潰し
- 末尾に必ず `exit 0`

### Hook stdin の payload
Claude Code が hooks に渡す stdin は JSON で `session_id` (skill 側の `${CLAUDE_SESSION_ID}` と同一) と `hook_event_name` を含む。
```bash
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
```
`// empty` を付けると `null` も空に丸まって扱いやすい。

### settings.json の jq マージ (idempotent)
hooks エントリを既存配列に append するとき、**重複を防ぐため** `command` 完全一致をチェック:
```bash
jq --arg event "$event" --arg cmd "$script" '
  .hooks //= {} |
  .hooks[$event] //= [] |
  if (.hooks[$event] | map(.hooks[]?.command // empty) | any(. == $cmd)) then
    .
  else
    .hooks[$event] += [{"hooks": [{"type": "command", "command": $cmd}]}]
  end
'
```
- `//=` で「nil なら default で初期化」(これで hooks key が無い settings.json も扱える)
- `.hooks[]?.command // empty` で nested 配列を flatten しつつ「該当 key 無し」も握り潰し
- バックアップは `cp ${CLAUDE_SETTINGS} ${CLAUDE_SETTINGS}.bak.$(date +%Y%m%d-%H%M%S)`

### Swift `@MainActor` クラスでの `static` プロパティ
`@MainActor final class Foo { ... static var x: ... }` の static は MainActor isolated になる。
`init(... = Foo.x)` のデフォルト値は **nonisolated コンテキスト** で評価されるので Swift 6 では型エラー。
解決:
```swift
nonisolated static var defaultSessionsDir: URL { ... }
```
Static が State を持たない pure な計算なら nonisolated にして問題ない。

### DispatchSource のイベントマスクは複数指定する
ディレクトリ監視で `[.write]` だけだと `mv` (= unlink + rename) を取りこぼすことがある。`[.write, .delete, .rename]` を全部指定すると確実。
さらに atomic mv は連続イベントを生むので、`DispatchWorkItem` で 100ms スロットルしてから main で発火させる。

### ObservableObject の reload 中のメインスレッド保証
`@MainActor final class SessionStore: ObservableObject` にしておけば `@Published` は MainActor で発行される。
FileWatcher のコールバックは別 queue で来るので `Task { @MainActor in self?.reload() }` で main に戻す。

## Phase 3

### NSWindow.performDrag(with:) は modal
borderless ウィンドウでドラッグ移動する標準 API は `performDrag(with:)` だが **mouseUp が来るまでブロックする** (modal-like)。なので:
- `performDrag(with:)` が return した瞬間 = ドラッグ完了
- mouseUp イベントは OS が消費するので mouseUp ハンドラには来ない
- ドラッグ完了処理 (位置永続化) は performDrag 直後に書く

クリック / ドラッグの 5px 閾値判定 (SPEC §6):
```swift
override func mouseDragged(with event: NSEvent) {
    let dist = hypot(cur.x - start.x, cur.y - start.y)
    if dist > 5 && !didDrag {
        didDrag = true
        performDrag(with: event)
        onDragEnd?(self.frame.origin)
    }
}
override func mouseUp(with event: NSEvent) {
    if !didDrag { onClick?() }   // 5px 以下のクリック扱い
}
```

### Swift 6 strict concurrency: @MainActor 型のデフォルト引数評価
`@MainActor final class Foo` のプロパティ初期化で `Foo()` を呼べるのは MainActor からだけ。
別の `@MainActor` 型の `init(x: Foo = Foo())` のデフォルト引数は **caller の context で評価される** ため、Swift 6 では「nonisolated context から MainActor init 呼んでる」と弾かれる。
解決:
- デフォルト引数を消して呼び出し側で明示的に渡す
- AppDelegate (@MainActor) のプロパティ初期化なら `private let manager = MascotWindowManager(positionStore: PositionStore())` と書ける

### PositionStore の atomic write
`FileManager.replaceItemAt(_:withItemAt:)` は tmp と本物を入れ替える atomic 操作。中間状態を絶対に作らない。
```swift
try data.write(to: tmp, options: .atomic)
_ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
```

### MascotView から onTapGesture を外して NSWindow にイベントを集約
SwiftUI で `.onTapGesture` を持つと `NSHostingView` が click を消費して NSWindow まで届かない。
**drag/click を NSWindow 側で 1 箇所に統一** するため:
- `MascotView` は表示専用 (Tap 検出を持たない)
- `MascotWindow` の mouseDown/mouseDragged/mouseUp で全部捌く
- `.help()` (tooltip) は hover 用なので残しても click は消費しない

### マウスオーバー時のカーソル変更 (pointer)
`NSHostingView` をサブクラスして `resetCursorRects` をオーバーライドし、`addCursorRect(bounds, cursor: .pointingHand)`。
OS が rect の入退出を勝手に処理してくれるので mouseEntered/Exited を手動で扱わなくて済む。`onHover` + `NSCursor.set()` よりロバスト。

## Phase 4

### SVG/PNG vs SwiftUI Canvas
SPEC §11 は「SVG → PNG ラスタライズで Resources/sprites/*.png」を想定。だが今回は **SwiftUI Canvas で ASCII テキストから直接描画** する方式に変更:
- 外部依存 (ImageMagick / rsvg-convert) ゼロ
- Resources / Bundle 管理不要
- 解像度独立 (HiDPI で綺麗)
- 表情の調整は creature 種ごとに 1 ファイル (`ChickModel.swift` / `LizardModel.swift` 等) で完結

Cell サイズは描画時に枠サイズ ÷ grid 幅で決まる。Path の `floor(x)` + `ceil(width + 0.5)` で隣接セル間に隙間が出ないようにする (アンチエイリアス対策)。

### ASCII を pixel grid に変換するときの validation
タイポで列数がズレるとレイアウト崩壊。debug build で全行 16 文字に揃っているか `assert` する:
```swift
#if DEBUG
assert(art.height == 16)
for (i, row) in art.cells.enumerated() {
    assert(row.count == 16, "row \(i) width=\(row.count) (must be 16)")
}
#endif
```

### TimelineView で時刻ベースのフレーム index
`Timer.publish(every: interval)` で interval を Emotion ごとに変えると publisher の identity が変わって subscription 不安定。
**`TimelineView(.periodic(from: .now, by: interval))`** だと SwiftUI が timeline を一括管理し、`context.date` から絶対時刻ベースで index を計算できる。Emotion 切替で frame index reset を考えなくてよい:
```swift
TimelineView(.periodic(from: .now, by: interval)) { context in
    let elapsed = context.date.timeIntervalSinceReferenceDate
    let idx = Int(elapsed / interval) % frames.count
    PixelArtView(art: frames[idx])
}
```

### SPEC §11 との解釈差: 「ドット絵」
SPEC §11 は実 PNG ファイル (SVG → ラスタライズ) を想定。今回は SwiftUI Canvas で同じ pixel 粒度を実現したので結果は同じ。実装コスト (アセット管理 vs. コード描画) と保守性で後者を選んだ。SPEC は "想定実装"、結果が同じなら逸脱して OK という判断。
