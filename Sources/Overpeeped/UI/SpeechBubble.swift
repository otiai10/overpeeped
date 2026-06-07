import SwiftUI

/// 角丸の本体 + 上辺中央から上へ伸びる三角の「しっぽ」を持つ吹き出し。
///
/// しっぽが上辺にあるので、吹き出しの真上にいるマスコットが喋っているように見える。
/// `MascotView` のミッション表示で、下端の吹き出しを上のマスコットに紐づけるのに使う。
struct SpeechBubble: Shape {
    var cornerRadius: CGFloat = 9
    var tailWidth: CGFloat = 13
    var tailHeight: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 本体: しっぽ分だけ上を空けた角丸長方形
        let bodyRect = CGRect(
            x: rect.minX,
            y: rect.minY + tailHeight,
            width: rect.width,
            height: max(0, rect.height - tailHeight)
        )
        let r = min(cornerRadius, min(bodyRect.width, bodyRect.height) / 2)
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: r, height: r))

        // しっぽ: 上辺中央から上向きの三角。本体と 0.5px 重ねて継ぎ目を消す。
        let midX = rect.midX
        let baseY = bodyRect.minY + 0.5
        let half = tailWidth / 2
        var tail = Path()
        tail.move(to: CGPoint(x: midX - half, y: baseY))
        tail.addLine(to: CGPoint(x: midX, y: rect.minY))
        tail.addLine(to: CGPoint(x: midX + half, y: baseY))
        tail.closeSubpath()
        path.addPath(tail)

        return path
    }
}
