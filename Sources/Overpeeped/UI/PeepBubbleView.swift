import SwiftUI

/// 鳴き声バブル。
///
/// 表示テキストは:
/// - `emotion.isThoughtBubble` (= thinking) なら universal な 💭 思考バブル (常時表示)
/// - それ以外は `model.cry(for:)` の creature 固有の鳴き声 (1.5 秒間隔フラッシュ)
/// - `cry` が `nil` (focused / sulking) なら何も表示しない
///
/// Emotion 切替時は再度フラッシュ。
struct PeepBubbleView: View {
    let model: MascotModel
    let emotion: Emotion

    @State private var visible: Bool = false

    /// 💭 は creature 非依存なので Emotion 側、鳴き声は creature 固有なので model 側から引く。
    private var bubbleText: String? {
        if emotion.isThoughtBubble { return "💭" }
        return model.cry(for: emotion)
    }

    var body: some View {
        Group {
            if let text = bubbleText {
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
            visible = (bubbleText != nil)
        }
        .onChange(of: emotion) { _, _ in
            // 表情が変わった瞬間に「鳴く」と目立つ (SPEC §5)
            visible = (bubbleText != nil)
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            if emotion.isThoughtBubble {
                visible = true        // 思考バブルは点滅させずずっと表示
            } else if bubbleText != nil {
                visible.toggle()      // 鳴き声は 1.5 秒間隔フラッシュ
            } else {
                visible = false
            }
        }
    }
}
