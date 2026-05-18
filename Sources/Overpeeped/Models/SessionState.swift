import Foundation

struct AgentSessionRef: Codable, Equatable {
    static let claudeCodeKind = "claude_code"

    let kind: String
    let sessionId: String

    static func claudeCode(sessionId: String) -> AgentSessionRef {
        AgentSessionRef(kind: claudeCodeKind, sessionId: sessionId)
    }
}

struct TerminalRef: Codable, Equatable {
    static let ghosttyKind = "ghostty"

    let kind: String
    let id: String

    static func ghostty(id: String) -> TerminalRef {
        TerminalRef(kind: ghosttyKind, id: id)
    }
}

/// `~/.overpeeped/sessions/<chick_uuid>.json` のスキーマに対応する Codable 型。
///
/// peep skill / Hooks がこのファイルを書き、Swift 側 (FileWatcher → SessionStore) が読む。
/// Swift は書き込み側ではないので custom encode は持たない。
struct SessionState: Codable, Equatable, Identifiable {
    let chickUuid: String
    let agent: AgentSessionRef
    let terminal: TerminalRef
    let projectName: String
    var nickname: String?
    let cwd: String
    let state: State
    let startedAt: Date
    let lastActivityAt: Date
    let lastStateChangeAt: Date

    var id: String { chickUuid }
    var sessionId: String { agent.sessionId }

    enum State: String, Codable, CaseIterable {
        case thinking   // UserPromptSubmit ~ 最初の PreToolUse まで (ツール選定中)
        case working    // PreToolUse / PostToolUse 中 (ツール実行中)
        case asking     // user の入力を待っている状態: Notification (permission_request) /
                        //                          PreToolUse (AskUserQuestion, ExitPlanMode)
        case idle       // Notification (idle / その他) — 単なる入力待ち
        case done       // Stop — 応答完了

        // 旧スキーマ "waiting" を idle にマップする backward compat
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            switch raw {
            case "thinking": self = .thinking
            case "working":  self = .working
            case "asking":   self = .asking
            case "idle":     self = .idle
            case "waiting":  self = .idle      // legacy
            case "done":     self = .done
            default:         self = .working   // unknown は安全側で working
            }
        }
    }
}

extension SessionState {
    static func decode(from data: Data) throws -> SessionState {
        try Self.decoder.decode(SessionState.self, from: data)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension SessionState {
    /// 旧スキーマ (flat な session_id / ghostty_terminal_uuid) で書かれた on-disk file との
    /// backward compat 用キー。新スキーマには対応する stored property が無いので
    /// synthesized CodingKeys には混ぜず、ここでだけ参照する。
    private enum LegacyKeys: String, CodingKey {
        case sessionId
        case ghosttyTerminalUuid
    }

    /// 旧スキーマの on-disk file を読み込めるよう、agent / terminal が無ければ
    /// flat な session_id / ghostty_terminal_uuid から組み立てる。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let agent: AgentSessionRef
        if let nested = try c.decodeIfPresent(AgentSessionRef.self, forKey: .agent) {
            agent = nested
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            agent = .claudeCode(sessionId: try legacy.decode(String.self, forKey: .sessionId))
        }

        let terminal: TerminalRef
        if let nested = try c.decodeIfPresent(TerminalRef.self, forKey: .terminal) {
            terminal = nested
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            terminal = .ghostty(id: try legacy.decode(String.self, forKey: .ghosttyTerminalUuid))
        }

        self.chickUuid          = try c.decode(String.self, forKey: .chickUuid)
        self.agent              = agent
        self.terminal           = terminal
        self.projectName        = try c.decode(String.self, forKey: .projectName)
        self.nickname           = try c.decodeIfPresent(String.self, forKey: .nickname)
        self.cwd                = try c.decode(String.self, forKey: .cwd)
        self.state              = try c.decode(State.self, forKey: .state)
        self.startedAt          = try c.decode(Date.self, forKey: .startedAt)
        self.lastActivityAt     = try c.decode(Date.self, forKey: .lastActivityAt)
        self.lastStateChangeAt  = try c.decode(Date.self, forKey: .lastStateChangeAt)
    }
}
