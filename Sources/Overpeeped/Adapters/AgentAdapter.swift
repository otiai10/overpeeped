import Foundation

/// メニューバー側の文言など、agent 種別ごとに変えたい UI 文言を提供する。
/// 将来 Claude Code 以外を扱うときに増やす。今は 1 種のみ。
protocol AgentAdapter {
    var kind: String { get }
    var displayName: String { get }
    var statusToolTip: String { get }
    var emptyStateHint: String { get }
}

struct ClaudeCodeAgentAdapter: AgentAdapter {
    let kind = AgentSessionRef.claudeCodeKind
    let displayName = "Claude Code"
    let statusToolTip = "overpeeped — Claude Code session monitor"
    let emptyStateHint = "Claude Code セッション内で /peep"
}

enum AgentAdapters {
    /// 現状サポートする agent が Claude Code 1 種のみなので、UI 文言用の
    /// 既定 adapter を 1 個だけ持つ。複数 agent (Cursor / Aider 等) を扱う
    /// ようになったら、active session の agent.kind から動的に組む形へ拡張する。
    static let defaultAdapter: any AgentAdapter = ClaudeCodeAgentAdapter()
}
