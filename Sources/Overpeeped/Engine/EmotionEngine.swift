import Foundation

/// SPEC §5 のテーブル通り `(state, elapsed)` → `Emotion` を返す純関数。
enum EmotionEngine {
    static func emotion(state: SessionState.State, elapsedSinceStateChange seconds: TimeInterval) -> Emotion {
        switch state {
        case .working:
            return .focused

        case .waiting:
            switch seconds {
            case ..<30:    return .expectant
            case ..<120:   return .impatient
            case ..<300:   return .angry
            default:       return .sad
            }

        case .done:
            switch seconds {
            case ..<60:    return .happy
            case ..<300:   return .lonely
            default:       return .sulking
            }
        }
    }

    /// `SessionState` から `now` を基準に Emotion を求める便利関数。
    static func emotion(for session: SessionState, now: Date = Date()) -> Emotion {
        let elapsed = now.timeIntervalSince(session.lastStateChangeAt)
        return emotion(state: session.state, elapsedSinceStateChange: max(0, elapsed))
    }
}
