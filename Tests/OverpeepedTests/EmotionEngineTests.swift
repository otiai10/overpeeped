import XCTest
@testable import Overpeeped

final class EmotionEngineTests: XCTestCase {
    // MARK: thinking — 常に thinking
    func testThinkingIsAlwaysThinking() {
        XCTAssertEqual(EmotionEngine.emotion(state: .thinking, elapsedSinceStateChange: 0), .thinking)
        XCTAssertEqual(EmotionEngine.emotion(state: .thinking, elapsedSinceStateChange: 9999), .thinking)
    }

    // MARK: working — 常に focused
    func testWorkingIsAlwaysFocused() {
        XCTAssertEqual(EmotionEngine.emotion(state: .working, elapsedSinceStateChange: 0), .focused)
        XCTAssertEqual(EmotionEngine.emotion(state: .working, elapsedSinceStateChange: 9999), .focused)
    }

    // MARK: idle / asking boundaries
    func testIdleAndAskingHeatUpBoundaries() {
        for state in [SessionState.State.idle, .asking] {
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 0),    .expectant)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 29),   .expectant)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 30),   .impatient)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 119),  .impatient)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 120),  .angry)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 299),  .angry)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 300),  .sad)
            XCTAssertEqual(EmotionEngine.emotion(state: state, elapsedSinceStateChange: 9999), .sad)
        }
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

    // MARK: balloon 仕様
    func testFocusedAndSulkingAreSilent() {
        XCTAssertNil(Emotion.focused.peepText)
        XCTAssertNil(Emotion.sulking.peepText)
    }

    func testThinkingShowsThoughtBubble() {
        // thinking は 鳴き声ではなく 💭 思考バブル (常時表示)
        XCTAssertEqual(Emotion.thinking.peepText, "💭")
        XCTAssertTrue(Emotion.thinking.isThoughtBubble)
    }

    func testNonThinkingAreNotThoughtBubbles() {
        for e in Emotion.allCases where e != .thinking {
            XCTAssertFalse(e.isThoughtBubble, "\(e) should not be a thought bubble")
        }
    }

    func testEmotionsWithBalloonAreVocal() {
        let silent: Set<Emotion> = [.focused, .sulking]
        for e in Emotion.allCases where !silent.contains(e) {
            XCTAssertNotNil(e.peepText, "\(e) should show a balloon")
        }
    }

    // MARK: SessionState からの計算
    func testEmotionFromSession() {
        let now = Date()
        let s = SessionState(
            chickUuid: "x", sessionId: "y", ghosttyTerminalUuid: "z",
            projectName: "p", nickname: nil, cwd: "/",
            state: .idle,
            startedAt: now,
            lastActivityAt: now,
            lastStateChangeAt: now.addingTimeInterval(-150) // 2.5 min ago
        )
        XCTAssertEqual(EmotionEngine.emotion(for: s, now: now), .angry)
    }
}
