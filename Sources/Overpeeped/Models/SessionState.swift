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
        case working
        case waiting
        case done
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
