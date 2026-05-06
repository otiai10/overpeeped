import Foundation

/// SPEC §5 の状態遷移テーブル準拠の感情。
///
/// `(state, elapsed_since_last_state_change)` から `EmotionEngine` で導出する。
enum Emotion: String, CaseIterable {
    case focused
    case expectant
    case impatient
    case angry
    case sad
    case happy
    case lonely
    case sulking

    /// 鳴き声テキスト。`focused` と `sulking` は鳴かない (集中中・拗ね中は静か)。
    var peepText: String? {
        switch self {
        case .focused, .sulking: return nil
        case .expectant:         return "ぴよ?"
        case .impatient:         return "ぴよぴよっ"
        case .angry:             return "ピヨーッ!"
        case .sad:               return "ぴ...よ..."
        case .happy:             return "ぴよっ♪"
        case .lonely:            return "ぴよ..."
        }
    }

    /// Phase 4 までドット絵が無い間の暫定表現 (絵文字フォールバック)。
    var emojiFallback: String {
        switch self {
        case .focused:   return "🐥"
        case .expectant: return "🐣"
        case .impatient: return "😤"
        case .angry:     return "😠"
        case .sad:       return "😢"
        case .happy:     return "✨"
        case .lonely:    return "🥺"
        case .sulking:   return "🙄"
        }
    }
}
