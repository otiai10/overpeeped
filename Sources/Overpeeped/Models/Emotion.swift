import Foundation

/// SPEC §5 の状態遷移テーブル準拠の感情。
///
/// `(state, elapsed_since_last_state_change)` から `EmotionEngine` で導出する。
enum Emotion: String, CaseIterable {
    case thinking   // ツール選定中: 静か
    case focused    // ツール実行中: 右向き歩行
    case expectant
    case impatient
    case angry
    case sad
    case happy
    case lonely
    case sulking

    /// 吹き出しテキスト。
    /// - `thinking` は鳴き声ではなく **思考バブル** として `💭` を出す (= 常時表示モード)。
    /// - `focused`/`sulking` は無音。
    /// - その他は鳴き声 (= 1.5秒フラッシュ表示)。
    var peepText: String? {
        switch self {
        case .thinking:           return "💭"
        case .focused, .sulking:  return nil
        case .expectant:          return "ぴよ?"
        case .impatient:          return "ぴよぴよっ"
        case .angry:              return "ピヨーッ!"
        case .sad:                return "ぴ...よ..."
        case .happy:              return "ぴよっ♪"
        case .lonely:             return "ぴよ..."
        }
    }

    /// `true` なら balloon は常時表示 (フラッシュしない)。
    /// 思考バブルは「鳴いている」のではなく「考えている」表現なので明滅しない。
    var isThoughtBubble: Bool {
        self == .thinking
    }

    /// Phase 4 までドット絵が無い間の暫定表現 (絵文字フォールバック)。
    var emojiFallback: String {
        switch self {
        case .thinking:  return "🤔"
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
