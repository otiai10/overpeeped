import AppKit
import Combine

/// macOS のメニューバー右側 (NSStatusBar) に常駐する 🐥 アイコンとメニュー。
/// SessionStore.sessions の変化を購読して、メニュー項目をリアルタイム更新する。
///
/// メニュー構成:
/// ```
/// 🐥×3  💭×1 🐥×1 🍗×1                ← 状態サマリ (disabled header)
/// ─────────────────────────────────
/// mike (overpeeped)        working    ← クリックで該当 Ghostty terminal にフォーカス
/// xleague-stats-sync       🍗 sad
/// xleague-digital          done
/// ─────────────────────────────────
/// ヒナを隠す / 表示する     ⌘H
/// ─────────────────────────────────
/// Overpeeped を終了        ⌘Q
/// ```
@MainActor
final class MenuBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private weak var manager: MascotWindowManager?
    private var cancellable: AnyCancellable?

    init(store: SessionStore, manager: MascotWindowManager) {
        self.manager = manager
        super.init()

        if let button = statusItem.button {
            button.title = "🐥"
            button.toolTip = AgentAdapters.defaultAdapter.statusToolTip
        }
        statusItem.menu = menu

        // 初期描画 (空)
        rebuildMenu(sessions: [])

        cancellable = store.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.rebuildMenu(sessions: sessions)
            }
    }

    // MARK: - Menu rebuild

    private func rebuildMenu(sessions: [SessionState]) {
        lastSessions = sessions
        menu.removeAllItems()

        // ─── header: マスコット数 + 感情サマリ
        let header = NSMenuItem(
            title: headerText(sessions: sessions),
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // ─── 各マスコット
        if sessions.isEmpty {
            let empty = NSMenuItem(title: "ヒナはまだいません  (\(AgentAdapters.defaultAdapter.emptyStateHint))", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for s in sessions {
                menu.addItem(mascotMenuItem(for: s))
            }
        }

        menu.addItem(.separator())

        // ─── hide/show toggle
        let visibilityTitle = (manager?.allHidden ?? false) ? "ヒナを表示" : "ヒナを隠す"
        let visibility = NSMenuItem(title: visibilityTitle, action: #selector(toggleVisibility), keyEquivalent: "h")
        visibility.target = self
        menu.addItem(visibility)

        menu.addItem(.separator())

        // ─── quit
        let quit = NSMenuItem(title: "Overpeeped を終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func headerText(sessions: [SessionState]) -> String {
        guard !sessions.isEmpty else {
            return "🐥 overpeeped — 0 chicks"
        }
        // 状態カウント: emoji×N
        var counts: [Emotion: Int] = [:]
        let now = Date()
        for s in sessions {
            counts[EmotionEngine.emotion(for: s, now: now), default: 0] += 1
        }
        // 表示順を fixed 順に (allCases 順)
        let summary = Emotion.allCases
            .compactMap { e -> String? in
                guard let n = counts[e] else { return nil }
                return "\(e.emojiFallback)×\(n)"
            }
            .joined(separator: " ")
        return "🐥×\(sessions.count)   \(summary)"
    }

    private func mascotMenuItem(for session: SessionState) -> NSMenuItem {
        let label: String = {
            if let n = session.nickname, !n.isEmpty { return "\(n) (\(session.projectName))" }
            return session.projectName
        }()
        let elapsed = Int(Date().timeIntervalSince(session.lastStateChangeAt))
        let stateLabel = "\(EmotionEngine.emotion(for: session).emojiFallback) \(session.state.rawValue) (\(elapsed)s)"
        let title = "\(label)    \(stateLabel)"

        let item = NSMenuItem(title: title, action: #selector(mascotClicked(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = session.terminal
        return item
    }

    // MARK: - Actions

    @objc private func mascotClicked(_ sender: NSMenuItem) {
        guard let terminal = sender.representedObject as? TerminalRef else { return }
        Log.click.info("via menubar terminal=\(terminal.id.shortLogId) kind=\(terminal.kind)")
        TerminalAdapters.focus(terminal)
    }

    @objc private func toggleVisibility() {
        manager?.toggleVisibility()
        // タイトル (ヒナを隠す ↔ ヒナを表示) を切り替えるためにメニューを再構築
        rebuildMenu(sessions: lastSessions)
    }

    /// rebuildMenu のたびに最新の sessions を記憶しておき、toggleVisibility 等の
    /// 即時メニュー再構築で参照する
    private var lastSessions: [SessionState] = []
}
