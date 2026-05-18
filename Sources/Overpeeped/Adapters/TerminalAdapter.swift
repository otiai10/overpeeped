import Foundation

/// kind ごとの terminal app との対話を担う。
/// 呼び出し側は `TerminalAdapters.focus(_:)` 経由でディスパッチするため、
/// 各 adapter は自分の kind を知らなくてよい (kind は dispatcher が握る)。
protocol TerminalAdapter {
    func focus(id: String) -> Bool
    func allTerminalIds() -> Set<String>?
}

enum TerminalAdapters {
    static func adapter(for kind: String) -> (any TerminalAdapter)? {
        switch kind {
        case TerminalRef.ghosttyKind:
            return GhosttyTerminalAdapter()
        default:
            return nil
        }
    }

    @discardableResult
    static func focus(_ terminal: TerminalRef) -> Bool {
        guard let adapter = adapter(for: terminal.kind) else {
            Log.focus.error("unsupported terminal kind=\(terminal.kind) id=\(terminal.id.shortLogId)")
            return false
        }
        return adapter.focus(id: terminal.id)
    }

    static func allTerminalIds(for kind: String) -> Set<String>? {
        adapter(for: kind)?.allTerminalIds()
    }
}
