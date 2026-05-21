import Foundation

/// SPEC §5 の状態遷移テーブル準拠の感情。
///
/// `(state, elapsed_since_last_state_change)` から `EmotionEngine` で導出する。
/// `Emotion` は creature 非依存の「意味」だけを持ち、見た目・鳴き声・テンポは
/// `MascotModel` 側 (chick / lizard / …) が担う。
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

    /// `true` なら balloon は 💭 思考バブル (常時表示、点滅しない)。
    ///
    /// 思考バブルは「鳴いている」のではなく「考えている」表現なので明滅しない。
    /// 実際の鳴き声 (creature 固有) は `MascotModel.cry(for:)` が返す。
    var isThoughtBubble: Bool {
        self == .thinking
    }

    /// メニューバーの感情サマリ表示に使う絵文字。
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
