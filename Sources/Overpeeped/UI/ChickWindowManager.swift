import AppKit
import SwiftUI

/// SessionStore.sessions を購読して、chick_uuid 単位で 1 NSWindow を作成・更新・破棄する。
///
/// - 追加: 新しい chick_uuid の SessionState が来たら NSWindow を作る
/// - 更新: 同じ chick_uuid の SessionState が来たら contentView を新しい ChickView で差し替え
/// - 削除: 既存 chick_uuid が消えた SessionState 群が来たら NSWindow を close
///
/// 初期位置は PositionStore に永続化された値があればそれを使い、無ければ
/// 画面右下から縦に 150px 間隔で空きを探して積む (SPEC §6)。
@MainActor
final class ChickWindowManager {
    private let positionStore: PositionStore
    private var windows: [String: ChickWindow] = [:]      // chick_uuid → window
    private var sessions: [String: SessionState] = [:]    // chick_uuid → latest session
    private var orphans: Set<String> = []                 // chick_uuid: terminal が消えた

    init(positionStore: PositionStore) {
        self.positionStore = positionStore
    }

    func update(sessions newSessions: [SessionState]) {
        let newDict = Dictionary(uniqueKeysWithValues: newSessions.map { ($0.chickUuid, $0) })

        // 1. 削除: 旧にあって新に無い chick_uuid を close
        let removed = Set(windows.keys).subtracting(newDict.keys)
        for uuid in removed {
            windows[uuid]?.close()
            windows.removeValue(forKey: uuid)
            orphans.remove(uuid)
        }

        // 2. orphan 検出: Ghostty 側の terminal id 集合と照合
        if let known = GhosttyAdapter.allTerminalIds() {
            var newOrphans: Set<String> = []
            for (uuid, s) in newDict where !known.contains(s.ghosttyTerminalUuid) {
                newOrphans.insert(uuid)
            }
            for uuid in newOrphans.subtracting(orphans) {
                Log.click.info("orphan detected chick=\(uuid.prefix(8)) — terminal vanished")
            }
            for uuid in orphans.subtracting(newOrphans) {
                Log.click.info("orphan recovered chick=\(uuid.prefix(8)) — terminal reappeared")
            }
            orphans = newOrphans
        }
        // Ghostty 不在 / AppleScript 失敗時は orphans を据え置き

        // 3. 追加 / 更新
        for (uuid, session) in newDict {
            let isOrphan = orphans.contains(uuid)
            if let existing = windows[uuid] {
                existing.contentView = ChickHostingView(rootView: ChickView(session: session, isOrphan: isOrphan))
            } else {
                let window = createWindow(for: session, isOrphan: isOrphan)
                windows[uuid] = window
                window.makeKeyAndOrderFront(nil)
            }
        }

        sessions = newDict
    }

    // MARK: - Private

    private func createWindow(for session: SessionState, isOrphan: Bool) -> ChickWindow {
        let chickUuid = session.chickUuid
        let window = ChickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 128),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = ChickHostingView(rootView: ChickView(session: session, isOrphan: isOrphan))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false

        // 初期位置: 永続化されていればそこ、無ければ右下から縦積み
        let origin = initialOrigin(forNewChickWith: window.frame.size, chickUuid: chickUuid)
        window.setFrameOrigin(origin)

        // ハンドラ: chickUuid を capture しつつ最新の session は self.sessions から引く
        window.onClick = { [weak self] in
            guard let self = self, let s = self.sessions[chickUuid] else { return }
            let label: String = {
                if let n = s.nickname, !n.isEmpty { return "\(n)/\(s.projectName)" }
                return s.projectName
            }()
            Log.click.info("chick=\(label) session=\(s.sessionId.prefix(8)) pane=\(s.ghosttyTerminalUuid.prefix(8)) cwd=\(s.cwd)")
            GhosttyAdapter.focus(terminalUUID: s.ghosttyTerminalUuid)
        }
        window.onDragEnd = { [weak self] origin in
            Log.drag.info("chick=\(chickUuid.prefix(8)) origin=(\(Int(origin.x)),\(Int(origin.y)))")
            self?.positionStore.save(position: origin, for: chickUuid)
        }

        return window
    }

    private func initialOrigin(forNewChickWith size: NSSize, chickUuid: String) -> NSPoint {
        if let saved = positionStore.position(for: chickUuid) {
            return saved
        }
        guard let screen = NSScreen.main else { return .zero }
        let f = screen.visibleFrame
        // 既存ウィンドウの数だけ縦に積む (右下基準で 150px 間隔)
        let stackIndex = windows.count
        return NSPoint(
            x: f.maxX - size.width - 32,
            y: f.minY + 32 + CGFloat(stackIndex) * 150
        )
    }
}
