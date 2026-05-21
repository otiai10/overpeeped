import Foundation

/// kind ごとの terminal app との対話を担う。
/// 呼び出し側は `TerminalAdapters.focus(_:)` 経由でディスパッチするため、
/// 各 adapter は自分の kind を知らなくてよい (kind は dispatcher が握る)。
///
/// 新 terminal 追加 (iTerm2 / Terminal.app / WezTerm 等) の手順:
///   1. `struct Foo TerminalAdapter: TerminalAdapter { ... }` を Adapters/ 配下に追加
///   2. `TerminalRef.fooKind` 定数を Models/SessionState.swift に追加
///   3. このファイルの `TerminalAdapters.adapter(for:)` switch に case を追加
///   4. Resources/skills/peep/scripts/detect-terminal.sh の case に対応する detector を追加
protocol TerminalAdapter {
    func focus(id: String) -> Bool
    func allTerminalIds() -> Set<String>?
}

enum TerminalAdapters {
    /// 新 terminal を足すときはこの switch に case を追加する。
    /// case 名は `TerminalRef.<name>Kind` 定数と一致させること。
    static func adapter(for kind: String) -> (any TerminalAdapter)? {
        switch kind {
        case TerminalRef.ghosttyKind:
            return GhosttyTerminalAdapter()
        // case TerminalRef.iterm2Kind:        return ITerm2TerminalAdapter()
        // case TerminalRef.terminalAppKind:   return TerminalAppAdapter()
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
