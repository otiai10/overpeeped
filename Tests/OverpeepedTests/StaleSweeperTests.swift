import XCTest
@testable import Overpeeped

final class StaleSweeperTests: XCTestCase {
    private var tmpDir: URL!
    private var sessionsDir: URL!
    private var indexURL: URL!

    override func setUpWithError() throws {
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("overpeeped-sweep-\(UUID().uuidString)")
        sessionsDir = tmpDir.appendingPathComponent("sessions")
        indexURL = tmpDir.appendingPathComponent("index.json")
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tmpDir)
    }

    /// session JSON を on-disk スキーマ (snake_case) で書く。
    private func writeSession(mascotUuid: String, sessionId: String, lastActivityAt: Date) throws {
        let iso = ISO8601DateFormatter()
        let ts = iso.string(from: lastActivityAt)
        let json = """
        {
          "mascot_uuid": "\(mascotUuid)",
          "agent": { "kind": "claude_code", "session_id": "\(sessionId)" },
          "terminal": { "kind": "ghostty", "id": "term-\(mascotUuid)" },
          "project_name": "p",
          "nickname": null,
          "cwd": "/",
          "state": "idle",
          "started_at": "\(ts)",
          "last_activity_at": "\(ts)",
          "last_state_change_at": "\(ts)"
        }
        """
        try json.write(to: sessionsDir.appendingPathComponent("\(mascotUuid).json"),
                       atomically: true, encoding: .utf8)
    }

    private func writeIndex(_ map: [String: String]) throws {
        let data = try JSONSerialization.data(withJSONObject: map)
        try data.write(to: indexURL)
    }

    private func sweep(now: Date) -> [String] {
        StaleSweeper.sweep(sessionsDir: sessionsDir, indexURL: indexURL,
                           threshold: 24 * 60 * 60, now: now)
    }

    /// 秒精度に丸めた現在時刻。on-disk タイムスタンプ (`ISO8601` / hooks の `date +%S`) は
    /// 秒精度なので、丸めておかないと round-trip でずれて境界テストが不安定になる。
    private var wholeSecondNow: Date {
        Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
    }

    /// 閾値を超えた session は削除、超えない session は残す。index も同期して刈られる。
    func testSweepsStaleKeepsFresh() throws {
        let now = wholeSecondNow
        try writeSession(mascotUuid: "stale-uuid", sessionId: "stale-sid",
                         lastActivityAt: now.addingTimeInterval(-48 * 60 * 60))   // 48h 前
        try writeSession(mascotUuid: "fresh-uuid", sessionId: "fresh-sid",
                         lastActivityAt: now.addingTimeInterval(-1 * 60 * 60))    // 1h 前
        try writeIndex(["stale-sid": "stale-uuid", "fresh-sid": "fresh-uuid"])

        let swept = sweep(now: now)

        XCTAssertEqual(swept, ["stale-uuid"])
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: sessionsDir.appendingPathComponent("stale-uuid.json").path))
        XCTAssertTrue(fm.fileExists(atPath: sessionsDir.appendingPathComponent("fresh-uuid.json").path))

        let index = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: indexURL))
        XCTAssertEqual(index, ["fresh-sid": "fresh-uuid"])
    }

    /// stale が無ければ何も消さず index も触らない。
    func testNoStaleLeavesEverythingIntact() throws {
        let now = wholeSecondNow
        try writeSession(mascotUuid: "fresh-uuid", sessionId: "fresh-sid",
                         lastActivityAt: now.addingTimeInterval(-60))
        try writeIndex(["fresh-sid": "fresh-uuid"])

        let swept = sweep(now: now)

        XCTAssertTrue(swept.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: sessionsDir.appendingPathComponent("fresh-uuid.json").path))
        let index = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: indexURL))
        XCTAssertEqual(index, ["fresh-sid": "fresh-uuid"])
    }

    /// 閾値ちょうどでは消さない (超えたときだけ stale)。
    func testThresholdBoundaryIsNotStale() throws {
        let now = wholeSecondNow
        try writeSession(mascotUuid: "edge-uuid", sessionId: "edge-sid",
                         lastActivityAt: now.addingTimeInterval(-24 * 60 * 60))   // ちょうど 24h
        try writeIndex(["edge-sid": "edge-uuid"])

        XCTAssertTrue(sweep(now: now).isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: sessionsDir.appendingPathComponent("edge-uuid.json").path))
    }

    /// sessions ディレクトリが無くてもクラッシュしない。
    func testMissingSessionsDirIsSafe() throws {
        try FileManager.default.removeItem(at: sessionsDir)
        XCTAssertTrue(sweep(now: Date()).isEmpty)
    }
}
