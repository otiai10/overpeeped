import SwiftUI

/// マスコット種 — たこ (octopus)。`mascot_model = "octopus"` で選択する。
///
/// ドット絵は 16×16 グリッド。正面向きで、丸い胴 (マントル) + 足を縦に大きく広げる。
/// dog / cat のような横向きは占有率が低く視認性に欠けたため、縦に占有率の高い種へ寄せた設計。
/// - 凡例:
///   - `.` 透明
///   - `o` 体 (珊瑚色)、`O` 体の影・アウトライン
///   - `B` 黒 (目)、`W` 白 (目ハイライト)、`p` 吸盤 (淡桃)
///   - `a` 興奮色 (angry)、`A` 濃い興奮色
///   - `d` くすんだ青灰 (sad)、`D` 濃いくすみ、`t` 涙、`s` キラキラ
struct OctopusModel: MascotModel {
    let id = "octopus"
    let displayName = "たこ"

    func frames(for emotion: Emotion) -> [PixelArt] {
        switch emotion {
        case .thinking:  return Self.focused
        case .focused:   return Self.focused
        case .expectant: return Self.expectant
        case .impatient: return Self.impatient
        case .angry:     return Self.angry
        case .sad:       return Self.sad
        case .happy:     return Self.happy
        case .lonely:    return Self.lonely
        case .sulking:   return Self.sulking
        }
    }

    func cry(for emotion: Emotion) -> String? {
        switch emotion {
        case .thinking, .focused, .sulking: return nil
        case .expectant:                    return "にゅ?"
        case .impatient:                    return "にゅるにゅる"
        case .angry:                        return "ニュルーッ!"
        case .sad:                          return "に...ゅ..."
        case .happy:                        return "にゅるん♪"
        case .lonely:                       return "にゅ..."
        }
    }

    // MARK: - Sprites

    private static let palette: [Character: Color] = [
        "o": Color(red: 0.92, green: 0.42, blue: 0.45),  // body
        "O": Color(red: 0.74, green: 0.28, blue: 0.34),  // body shadow / outline
        "B": Color(red: 0.10, green: 0.10, blue: 0.10),  // eye
        "W": Color.white,                                 // eye highlight
        "p": Color(red: 1.00, green: 0.80, blue: 0.82),  // suckers
        "a": Color(red: 0.86, green: 0.16, blue: 0.16),  // angry body
        "A": Color(red: 0.55, green: 0.08, blue: 0.08),  // angry dark
        "d": Color(red: 0.56, green: 0.54, blue: 0.66),  // sad dull
        "D": Color(red: 0.40, green: 0.38, blue: 0.50),  // sad dull dark
        "t": Color(red: 0.40, green: 0.64, blue: 0.98),  // tear
        "s": Color(red: 1.00, green: 0.95, blue: 0.60),  // sparkle
    ]

    private static func art(_ ascii: String) -> PixelArt {
        mascotPixelArt(ascii, palette: palette)
    }

    // focused — マントルをふくらませ、足をゆらゆら漂わせる (上下に 1px バウンド)
    private static let focused: [PixelArt] = [
        art("""
        ................
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .ooBWooooooBWoo.
        .ooBBooooooBBoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ................
        ................
        """),
        art("""
        ................
        ................
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .ooBWooooooBWoo.
        .ooBBooooooBBoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ................
        """),
    ]

    // expectant — 目をうるませ、足元できらきらが弾ける
    private static let expectant: [PixelArt] = [
        art("""
        ......s.........
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .oWBoooooooWBoo.
        .oBBoooooooBBoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ...............s
        ................
        """),
        art("""
        ......s.........
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .oWBoooooooWBoo.
        .oBBoooooooBBoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        .s..............
        ................
        """),
    ]

    // impatient — 目を細め、足を小刻みにバタつかせる
    private static let impatient: [PixelArt] = [
        art("""
        ................
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .ooOOooooooOOoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ................
        ................
        """),
        art("""
        ................
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .ooOOooooooOOoo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .o.oo.oo.oo.oo..
        .p..p..p..p..p..
        ................
        ................
        """),
    ]

    // angry — 真っ赤に染まり、吊り目で足を逆立てる。プルプル震え
    private static let angry: [PixelArt] = [
        art("""
        ................
        .....aaaaaa.....
        ...aaaaaaaaaa...
        ..aaaaaaaaaaaa..
        .aaaaaaaaaaaaaa.
        .aaaaaaaaaaaaaa.
        .aaBaaaaaaaaBaa.
        .aaABaaaaaaABaa.
        .aaaaaaaaaaaaaa.
        .aaaaaaaaaaaaaa.
        .aaaaaaaaaaaaaa.
        .aaaaaaaaaaaaaa.
        .aa.aa.aa.aa.aa.
        .A..A..A..A..A..
        ................
        ................
        """),
        art("""
        ................
        ......aaaaaa....
        ....aaaaaaaaaa..
        ...aaaaaaaaaaaa.
        ..aaaaaaaaaaaaaa
        ..aaaaaaaaaaaaaa
        ..aaBaaaaaaaaBaa
        ..aaABaaaaaaABaa
        ..aaaaaaaaaaaaaa
        ..aaaaaaaaaaaaaa
        ..aaaaaaaaaaaaaa
        ..aaaaaaaaaaaaaa
        ..aa.aa.aa.aa.aa
        ..A..A..A..A..A.
        ................
        ................
        """),
    ]

    // sad — くすんで足がだらりと垂れ、涙がこぼれる
    private static let sad: [PixelArt] = [
        art("""
        ................
        ................
        .....dddddd.....
        ...dddddddddd...
        ..dddddddddddd..
        .dddddddddddddd.
        .dddddddddddddd.
        .ddBddddddddBdd.
        .ddBddddddddBdd.
        .dddddddddddddd.
        .dddddddddddddd.
        .dddddddddddddd.
        .dd.dd.dd.dd.dd.
        ..D..D..D..D..D.
        .............t..
        ................
        """),
        art("""
        ................
        ................
        .....dddddd.....
        ...dddddddddd...
        ..dddddddddddd..
        .dddddddddddddd.
        .dddddddddddddd.
        .ddBddddddddBdd.
        .ddBddddddddBdd.
        .dddddddddddddd.
        .dddddddddddddd.
        .dddddddddddddd.
        .dd.dd.dd.dd.dd.
        ..D..D..D..D..D.
        ................
        .............t..
        """),
    ]

    // happy — にっこり笑って大きく弾む + ✨
    private static let happy: [PixelArt] = [
        art("""
        s..............s
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .oooooooooooooo.
        .ooBWooooooBWoo.
        .oooooooooooooo.
        .oooBooooooBooo.
        .oooBBBBBBBBooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ................
        s..............s
        """),
        art("""
        s..............s
        .....oooooo.....
        ...oooooooooo...
        ..oooooooooooo..
        .oooooooooooooo.
        .ooBWooooooBWoo.
        .oooooooooooooo.
        .oooBooooooBooo.
        .oooBBBBBBBBooo.
        .oooooooooooooo.
        .oooooooooooooo.
        .oo.oo.oo.oo.oo.
        ..p..p..p..p..p.
        ................
        ................
        s..............s
        """),
    ]

    // lonely — 小さくしぼんで、足を縮めこちらを見上げる
    private static let lonely: [PixelArt] = [
        art("""
        ................
        ................
        ................
        ......oooo......
        ....oooooooo....
        ...oooooooooo...
        ...oooooooooo...
        ...oBWooooBWo...
        ...oBBooooBBo...
        ...oooooooooo...
        ...oooooooooo...
        ....o.o.o.o.o...
        ................
        ................
        ................
        ................
        """),
    ]

    // sulking — 拗ね (背を向けて足をすぼめ、色をくすませる)
    private static let sulking: [PixelArt] = [
        art("""
        ................
        ................
        ......OOOO......
        ....OOOOOOOO....
        ...OOOOOOOOOO...
        ..OOOOOOOOOOOO..
        .OOOOOOOOOOOOOO.
        .OOOOOOOOOOOOOO.
        .OOOOOOOOOOOOOO.
        .OOOOOOOOOOOOOO.
        .OOOOOOOOOOOOOO.
        .OOOOOOOOOOOOOO.
        .OO.OO.OO.OO.OO.
        ..O..O..O..O..O.
        ................
        ................
        """),
    ]
}
