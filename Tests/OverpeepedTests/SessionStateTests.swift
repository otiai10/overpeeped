import XCTest
@testable import Overpeeped

final class SessionStateTests: XCTestCase {
    func testDecodeSpecSampleJSON() throws {
        // SPEC §4 のサンプルそのまま
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
        XCTAssertEqual(s.chickUuid, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(s.sessionId, "claude-sess-abc123")
        XCTAssertEqual(s.ghosttyTerminalUuid, "ghostty-term-xyz789")
        XCTAssertEqual(s.agent, .claudeCode(sessionId: "claude-sess-abc123"))
        XCTAssertEqual(s.terminal, .ghostty(id: "ghostty-term-xyz789"))
        XCTAssertEqual(s.projectName, "triax-hub")
        XCTAssertNil(s.nickname)
        XCTAssertEqual(s.cwd, "/Users/hiromu/src/triax/hub")
        XCTAssertEqual(s.state, .working)
    }

    func testDecodeAdapterSchemaJSON() throws {
        let json = """
        {
          "chick_uuid": "550e8400-e29b-41d4-a716-446655440000",
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
          "cwd": "/Users/hiromu/src/triax/hub",
          "state": "working",
          "started_at": "2026-05-06T10:30:00Z",
          "last_activity_at": "2026-05-06T10:32:15Z",
          "last_state_change_at": "2026-05-06T10:31:45Z"
        }
        """.data(using: .utf8)!

        let s = try SessionState.decode(from: json)
        XCTAssertEqual(s.agent.kind, AgentSessionRef.claudeCodeKind)
        XCTAssertEqual(s.sessionId, "claude-sess-abc123")
        XCTAssertEqual(s.terminal.kind, TerminalRef.ghosttyKind)
        XCTAssertEqual(s.ghosttyTerminalUuid, "ghostty-term-xyz789")
    }

    func testDecodeWithNickname() throws {
        let json = """
        {
          "chick_uuid": "abc",
          "session_id": "s1",
          "ghostty_terminal_uuid": "g1",
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
        XCTAssertEqual(s.nickname, "ピー助")
        XCTAssertEqual(s.state, .asking)
    }

    /// 旧スキーマ "waiting" は backward compat で .idle に decode される
    func testLegacyWaitingDecodesAsIdle() throws {
        let json = """
        {
          "chick_uuid": "abc",
          "session_id": "s1",
          "ghostty_terminal_uuid": "g1",
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

    func testIDEqualsChickUuid() throws {
        let s = SessionState(
            chickUuid: "the-id",
            agent: .claudeCode(sessionId: "x"),
            terminal: .ghostty(id: "y"),
            projectName: "p", nickname: nil, cwd: "/",
            state: .done,
            startedAt: Date(), lastActivityAt: Date(), lastStateChangeAt: Date()
        )
        XCTAssertEqual(s.id, "the-id")
    }
}
