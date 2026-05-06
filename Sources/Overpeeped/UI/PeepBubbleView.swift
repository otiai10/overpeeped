import SwiftUI

/// 鳴き声バブル。Emotion.peepText が nil なら何も表示しない (focused / sulking は静か)。
///
/// 表示中 1.5 秒、非表示 1.5 秒を繰り返す。Emotion 切替時は再度フラッシュ。
struct PeepBubbleView: View {
    let emotion: Emotion
    @State private var visible: Bool = false

    var body: some View {
        Group {
            if let text = emotion.peepText {
                Text(text)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.95))
                            .overlay(
                                Capsule()
                                    .stroke(Color.black.opacity(0.25), lineWidth: 0.8)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                    )
                    .opacity(visible ? 1 : 0)
                    .scaleEffect(visible ? 1 : 0.7, anchor: .bottom)
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: visible)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .onAppear {
            visible = (emotion.peepText != nil)
        }
        .onChange(of: emotion) { _, _ in
            // 表情が変わった瞬間に「鳴く」と目立つ (SPEC §5)
            visible = (emotion.peepText != nil)
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if emotion.peepText != nil {
                visible.toggle()
            } else {
                visible = false
            }
        }
    }
}
