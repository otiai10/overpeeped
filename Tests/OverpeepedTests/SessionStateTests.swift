import XCTest
@testable import Overpeeped

final class SessionStateTests: XCTestCase {
    /// 現行スキーマ: mascot_uuid + nested agent/terminal + mascot_model
    func testDecodeCurrentSchemaJSON() throws {
        let json = """
        {
          "mascot_uuid": "550e8400-e29b-41d4-a716-446655440000",
          "agent": {
            "kind": "claude_code",
            "session_id": "claude-sess-abc123"
          },
          "terminal": {
            "kind": "ghostty",
            "id": "ghostty-term-xyz789"
          },
          "project_name": "triax-hub",
          "nickname": null,
          "mascot_model": "lizard",
          "cwd": "/Users/hiromu/src/triax/hub",
          "state": "working",
          "started_at": "2026-05-06T10:30:00Z",
          "last_activity_at": "2026-05-06T10:32:15Z",
          "last_state_change_at": "2026-05-06T10:31:45Z"
        }
        """.data(using: .utf8)!

        let s = try SessionState.decode(from: json)
        XCTAssertEqual(s.mascotUuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(s.id, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(s.agent, .claudeCode(sessionId: "claude-sess-abc123"))
        XCTAssertEqual(s.terminal, .ghostty(id: "ghostty-term-xyz789"))
        XCTAssertEqual(s.projectName, "triax-hub")
        XCTAssertNil(s.nickname)
        XCTAssertEqual(s.mascotModel, "lizard")
        XCTAssertEqual(s.cwd, "/Users/hiromu/src/triax/hub")
        XCTAssertEqual(s.state, .working)
        XCTAssertNil(s.mission)   // mission キー無し → nil
    }

    /// mission キーがあれば decode され、無ければ nil (peep skill が後から書く optional フィールド)
    func testDecodeMission() throws {
        let withMission = """
        {
          "mascot_uuid": "abc",
          "agent": { "kind": "claude_code", "session_id": "s1" },
          "terminal": { "kind": "ghostty", "id": "g1" },
          "project_name": "p",
          "nickname": null,
          "mission": "#7 のミッション機能を実装",
          "cwd": "/",
          "state": "working",
          "started_at": "2026-01-01T00:00:00Z",
          "last_activity_at": "2026-01-01T00:00:00Z",
          "last_state_change_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        XCTAssertEqual(try SessionState.decode(from: withMission).mission, "#7 のミッション機能を実装")

        let nullMission = """
        {
          "mascot_uuid": "abc",
          "agent": { "kind": "claude_code", "session_id": "s1" },
          "terminal": { "kind": "ghostty", "id": "g1" },
          "project_name": "p",
          "nickname": null,
          "mission": null,
          "cwd": "/",
          "state": "working",
          "started_at": "2026-01-01T00:00:00Z",
          "last_activity_at": "2026-01-01T00:00:00Z",
          "last_state_change_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        XCTAssertNil(try SessionState.decode(from: nullMission).mission)
    }

    /// mascot_model 省略時は nil (→ Swift 側で既定の chick にフォールバック)
    func testDecodeWithoutMascotModel() throws {
        let json = """
        {
          "mascot_uuid": "abc",
          "agent": { "kind": "claude_code", "session_id": "s1" },
          "terminal": { "kind": "ghostty", "id": "g1" },
          "project_name": "p",
          "nickname": "ピー助",
          "cwd": "/",
          "state": "asking",
          "started_at": "2026-01-01T00:00:00Z",
          "last_activity_at": "2026-01-01T00:00:00Z",
          "last_state_change_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let s = try SessionState.decode(from: json)
        XCTAssertNil(s.mascotModel)
        XCTAssertEqual(s.nickname, "ピー助")
        XCTAssertEqual(s.state, .asking)
    }

    /// 旧スキーマ: chick_uuid + flat session_id / ghostty_terminal_uuid
    /// (マスコット pluggable 化前の on-disk file を読めること)
    func testDecodeLegacyChickSchemaJSON() throws {
        let json = """
        {
          "chick_uuid": "550e8400-e29b-41d4-a716-446655440000",
          "session_id": "claude-sess-abc123",
          "ghostty_terminal_uuid": "ghostty-term-xyz789",
          "project_name": "triax-hub",
          "nickname": null,
          "cwd": "/Users/hiromu/src/triax/hub",
          "state": "working",
          "started_at": "2026-05-06T10:30:00Z",
          "last_activity_at": "2026-05-06T10:32:15Z",
          "last_state_change_at": "2026-05-06T10:31:45Z"
        }
        """.data(using: .utf8)!

        let s = try SessionState.decode(from: json)
        XCTAssertEqual(s.mascotUuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(s.agent, .claudeCode(sessionId: "claude-sess-abc123"))
        XCTAssertEqual(s.terminal, .ghostty(id: "ghostty-term-xyz789"))
        XCTAssertNil(s.mascotModel)
        XCTAssertEqual(s.state, .working)
    }

    /// 旧スキーマ "waiting" は backward compat で .idle に decode される
    func testLegacyWaitingDecodesAsIdle() throws {
        let json = """
        {
          "mascot_uuid": "abc",
          "agent": { "kind": "claude_code", "session_id": "s1" },
          "terminal": { "kind": "ghostty", "id": "g1" },
          "project_name": "p",
          "nickname": null,
          "cwd": "/",
          "state": "waiting",
          "started_at": "2026-01-01T00:00:00Z",
          "last_activity_at": "2026-01-01T00:00:00Z",
          "last_state_change_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!
        let s = try SessionState.decode(from: json)
        XCTAssertEqual(s.state, .idle)
    }

    func testIDEqualsMascotUuid() throws {
        let s = SessionState(
            mascotUuid: "the-id",
            agent: .claudeCode(sessionId: "x"),
            terminal: .ghostty(id: "y"),
            projectName: "p", nickname: nil, mascotModel: nil, cwd: "/",
            state: .done,
            startedAt: Date(), lastActivityAt: Date(), lastStateChangeAt: Date()
        )
        XCTAssertEqual(s.id, "the-id")
    }
}
