import Foundation

/// `~/.overpeeped/sessions/<chick_uuid>.json` のスキーマに対応する Codable 型。
///
/// peep skill / Hooks がこのファイルを書き、Swift 側 (FileWatcher → SessionStore) が読む。
struct SessionState: Codable, Equatable, Identifiable {
    let chickUuid: String
    let sessionId: String
    let ghosttyTerminalUuid: String
    let projectName: String
    var nickname: String?
    let cwd: String
    let state: State
    let startedAt: Date
    let lastActivityAt: Date
    let lastStateChangeAt: Date

    var id: String { chickUuid }

    enum State: String, Codable, CaseIterable {
        case thinking   // UserPromptSubmit ~ 最初の PreToolUse まで (ツール選定中)
        case working    // PreToolUse / PostToolUse 中 (ツール実行中)
        case asking     // Notification (reason=permission_request) — 許可待ち
        case idle       // Notification (reason=idle / その他) — 単なる入力待ち
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
