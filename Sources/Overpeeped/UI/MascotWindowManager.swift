import AppKit
import SwiftUI

/// SessionStore.sessions を購読して、mascot_uuid 単位で 1 NSWindow を作成・更新・破棄する。
///
/// - 追加: 新しい mascot_uuid の SessionState が来たら NSWindow を作る
/// - 更新: 同じ mascot_uuid の SessionState が来たら contentView を新しい MascotView で差し替え
/// - 削除: 既存 mascot_uuid が消えた SessionState 群が来たら NSWindow を close
///
/// 初期位置は PositionStore に永続化された値があればそれを使い、無ければ
/// 画面右下から縦に 150px 間隔で空きを探して積む (SPEC §6)。
@MainActor
final class MascotWindowManager {
    private let positionStore: PositionStore
    private var windows: [String: MascotWindow] = [:]     // mascot_uuid → window
    private var sessions: [String: SessionState] = [:]    // mascot_uuid → latest session
    private var orphans: Set<String> = []                 // mascot_uuid: terminal が消えた
    private(set) var allHidden: Bool = false              // hideAll の効いている状態

    init(positionStore: PositionStore) {
        self.positionStore = positionStore
    }

    func hideAll() {
        allHidden = true
        for window in windows.values { window.orderOut(nil) }
    }

    func showAll() {
        allHidden = false
        for window in windows.values { window.orderFront(nil) }
    }

    func toggleVisibility() {
        allHidden ? showAll() : hideAll()
    }

    func update(sessions newSessions: [SessionState]) {
        let newDict = Dictionary(uniqueKeysWithValues: newSessions.map { ($0.mascotUuid, $0) })

        // 1. 削除: 旧にあって新に無い mascot_uuid を close
        let removed = Set(windows.keys).subtracting(newDict.keys)
        for uuid in removed {
            windows[uuid]?.close()
            windows.removeValue(forKey: uuid)
            orphans.remove(uuid)
        }

        // 2. orphan 検出: kind ごとに adapter から terminal id 集合を取り、newDict と照合する。
        //    adapter が nil を返した kind (terminal app 不在 / AppleScript 失敗) の session は
        //    前回の orphan 状態を据え置く。どの kind も応答しなければ orphans 全体を据え置く。
        var idsByKind: [String: Set<String>] = [:]
        for kind in Set(newDict.values.map(\.terminal.kind)) {
            if let ids = TerminalAdapters.allTerminalIds(for: kind) {
                idsByKind[kind] = ids
            }
        }
        if !idsByKind.isEmpty {
            var newOrphans: Set<String> = []
            for (uuid, s) in newDict {
                if let known = idsByKind[s.terminal.kind] {
                    if !known.contains(s.terminal.id) { newOrphans.insert(uuid) }
                } else if orphans.contains(uuid) {
                    newOrphans.insert(uuid)
                }
            }
            logOrphanChanges(from: orphans, to: newOrphans)
            orphans = newOrphans
        }

        // 3. 追加 / 更新
        for (uuid, session) in newDict {
            let isOrphan = orphans.contains(uuid)
            if let existing = windows[uuid] {
                existing.contentView = MascotHostingView(rootView: MascotView(session: session, isOrphan: isOrphan))
            } else {
                let window = createWindow(for: session, isOrphan: isOrphan)
                windows[uuid] = window
                window.makeKeyAndOrderFront(nil)
            }
        }

        sessions = newDict
    }

    // MARK: - Private

    private func createWindow(for session: SessionState, isOrphan: Bool) -> MascotWindow {
        let mascotUuid = session.mascotUuid
        let window = MascotWindow(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 128),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = MascotHostingView(rootView: MascotView(session: session, isOrphan: isOrphan))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false

        // 初期位置: 永続化されていればそこ、無ければ右下から縦積み
        let origin = initialOrigin(forNewMascotWith: window.frame.size, mascotUuid: mascotUuid)
        window.setFrameOrigin(origin)

        // ハンドラ: mascotUuid を capture しつつ最新の session は self.sessions から引く
        window.onClick = { [weak self] in
            guard let self = self, let s = self.sessions[mascotUuid] else { return }
            let label: String = {
                if let n = s.nickname, !n.isEmpty { return "\(n)/\(s.projectName)" }
                return s.projectName
            }()
            Log.click.info("mascot=\(label) agent=\(s.agent.kind) session=\(s.sessionId.shortLogId) terminal=\(s.terminal.id.shortLogId) kind=\(s.terminal.kind) cwd=\(s.cwd)")
            TerminalAdapters.focus(s.terminal)
        }
        window.onDragEnd = { [weak self] origin in
            Log.drag.info("mascot=\(mascotUuid.shortLogId) origin=(\(Int(origin.x)),\(Int(origin.y)))")
            self?.positionStore.save(position: origin, for: mascotUuid)
        }

        return window
    }

    private func initialOrigin(forNewMascotWith size: NSSize, mascotUuid: String) -> NSPoint {
        if let saved = positionStore.position(for: mascotUuid) {
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

    private func logOrphanChanges(from oldOrphans: Set<String>, to newOrphans: Set<String>) {
        for uuid in newOrphans.subtracting(oldOrphans) {
            Log.click.info("orphan detected mascot=\(uuid.shortLogId) — terminal vanished")
        }
        for uuid in oldOrphans.subtracting(newOrphans) {
            Log.click.info("orphan recovered mascot=\(uuid.shortLogId) — terminal reappeared")
        }
    }
}
