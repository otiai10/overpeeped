import SwiftUI

/// `Emotion` を受け取って「見た目・鳴き声・テンポ」を返す、差し替え可能なマスコット種。
///
/// `chick` を既定とし、`lizard` / `slime` / `octopus` / `robot` / `ghost` … を後から足せる。
/// 各 model を `MascotRegistry` に登録し、session JSON の `mascot_model` で選択する。
///
/// 設計方針:
/// - `Emotion` 自体は `EmotionEngine` が状態遷移から導く creature 非依存の「意味」。
///   model はその Emotion に対する **表現** (ドット絵・鳴き声・テンポ) だけを持つ。
/// - `frames` / `cry` は creature 固有なので必須。`frameDuration` は SPEC §5 の標準テンポを
///   protocol extension の default で提供し、独自リズムが要るときだけ override する。
protocol MascotModel {
    /// 永続化・設定で使う安定 ID (`"chick"`, `"lizard"`, …)。session JSON の `mascot_model` 値。
    var id: String { get }

    /// メニュー等で見せる表示名 (`"ひよこ"`, `"とかげ"`, …)。
    var displayName: String { get }

    /// `Emotion` ごとのドット絵フレーム (1〜3 枚)。**空配列を返してはならない。**
    func frames(for emotion: Emotion) -> [PixelArt]

    /// `Emotion` ごとのフレーム送り間隔。
    func frameDuration(for emotion: Emotion) -> TimeInterval

    /// `Emotion` ごとの鳴き声。`nil` は無音 (thinking / focused / sulking)。
    /// thinking は鳴き声ではなく 💭 思考バブルなので、ここでは `nil` を返す。
    func cry(for emotion: Emotion) -> String?
}

extension MascotModel {
    /// SPEC §5 の標準フレームスピード (200-500ms 目安、表情ごとに緩急)。
    /// creature 固有のリズムが要らなければこの default をそのまま使う。
    func frameDuration(for emotion: Emotion) -> TimeInterval {
        switch emotion {
        case .thinking:          return 0.80   // 考え中: ゆったり
        case .focused:           return 0.32   // 歩行リズム
        case .lonely, .sulking:  return 0.60   // ゆったり / 静止
        case .expectant:         return 0.35
        case .impatient:         return 0.20   // 足踏みパタパタ
        case .angry:             return 0.10   // プルプル震え
        case .sad:               return 0.90   // ぐったり (ゆったり)
        case .happy:             return 0.20   // ぴょんぴょん
        }
    }
}

/// 利用可能な `MascotModel` の登録簿。`mascot_model` 文字列から実体を解決する。
enum MascotRegistry {
    /// 既定モデル ID。`mascot_model` が未指定 / 未知のときのフォールバック。
    static let defaultID = "chick"

    private static let models: [String: MascotModel] = {
        let all: [MascotModel] = [
            ChickModel(), LizardModel(), SlimeModel(), OctopusModel(), RobotModel(), GhostModel(),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    /// 登録済みモデル一覧。
    static var all: [MascotModel] { Array(models.values) }

    /// `mascot_model` 値からモデルを解決する。`nil` / 未知 ID は既定 (chick) にフォールバック。
    static func model(id: String?) -> MascotModel {
        if let id, let model = models[id] { return model }
        return models[defaultID]!
    }
}

/// ASCII テキストから `PixelArt` を生成する共通ヘルパ。
///
/// DEBUG ビルドでは `gridSize`×`gridSize` 厳守を assert する (タイポでズレるとレイアウト崩壊)。
func mascotPixelArt(_ ascii: String, palette: [Character: Color], gridSize: Int = 16) -> PixelArt {
    let art = PixelArt(ascii, palette: palette)
    #if DEBUG
    assert(art.height == gridSize, "mascotPixelArt: expected \(gridSize) rows, got \(art.height)")
    for (i, row) in art.cells.enumerated() {
        assert(row.count == gridSize, "mascotPixelArt: row \(i) width=\(row.count) (must be \(gridSize))")
    }
    #endif
    return art
}
