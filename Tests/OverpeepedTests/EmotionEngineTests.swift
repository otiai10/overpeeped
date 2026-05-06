import XCTest
@testable import Overpeeped

final class EmotionEngineTests: XCTestCase {
    // MARK: working
    func testWorkingIsAlwaysFocused() {
        XCTAssertEqual(EmotionEngine.emotion(state: .working, elapsedSinceStateChange: 0), .focused)
        XCTAssertEqual(EmotionEngine.emotion(state: .working, elapsedSinceStateChange: 9999), .focused)
    }

    // MARK: waiting boundaries (SPEC §5)
    func testWaitingBoundaries() {
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 0),    .expectant)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 29),   .expectant)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 30),   .impatient)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 119),  .impatient)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 120),  .angry)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 299),  .angry)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 300),  .sad)
        XCTAssertEqual(EmotionEngine.emotion(state: .waiting, elapsedSinceStateChange: 9999), .sad)
    }

    // MARK: done boundaries (SPEC §5)
    func testDoneBoundaries() {
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 0),    .happy)
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 59),   .happy)
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 60),   .lonely)
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 299),  .lonely)
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 300),  .sulking)
        XCTAssertEqual(EmotionEngine.emotion(state: .done, elapsedSinceStateChange: 9999), .sulking)
    }

    // MARK: peepText 仕様
    func testFocusedAndSulkingAreSilent() {
        XCTAssertNil(Emotion.focused.peepText)
        XCTAssertNil(Emotion.sulking.peepText)
    }

    func testOtherEmotionsAreVocal() {
        for e in Emotion.allCases where e != .focused && e != .sulking {
            XCTAssertNotNil(e.peepText, "\(e) should have a peep text")
        }
    }

    // MARK: SessionState からの計算
    func testEmotionFromSession() {
        let now = Date()
        let s = SessionState(
            chickUuid: "x", sessionId: "y", ghosttyTerminalUuid: "z",
            projectName: "p", nickname: nil, cwd: "/",
            state: .waiting,
            startedAt: now,
            lastActivityAt: now,
            lastStateChangeAt: now.addingTimeInterval(-150) // 2.5 min ago
        )
        XCTAssertEqual(EmotionEngine.emotion(for: s, now: now), .angry)
    }
}
