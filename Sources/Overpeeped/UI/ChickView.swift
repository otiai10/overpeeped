import SwiftUI

/// 1 セッションのヒナを描画する (Phase 4):
/// - `AnimatedChickView`: Emotion ごとのドット絵フレームをアニメーション
/// - `PeepBubbleView`: 鳴き声テキストを 1.5 秒間隔でフラッシュ
/// - 状態切替時はフェードで遷移
///
/// クリック検出は ChickWindow 側 (5px 閾値で drag/click 区別)。ここはイベントを持たない。
struct ChickView: View {
    let session: SessionState

    @State private var now: Date = Date()

    private var emotion: Emotion {
        EmotionEngine.emotion(for: session, now: now)
    }

    private var tooltip: String {
        let name: String
        if let nick = session.nickname, !nick.isEmpty {
            name = "\(nick) (\(session.projectName))"
        } else {
            name = session.projectName
        }
        let elapsed = Int(now.timeIntervalSince(session.lastStateChangeAt))
        return "\(name)\n状態: \(session.state.rawValue) / \(elapsed)秒"
    }

    var body: some View {
        ZStack(alignment: .top) {
            // ドット絵: 上部 16px をバブル領域として残し、その下にヒナ本体
            AnimatedChickView(emotion: emotion)
                .frame(width: 112, height: 112)
                .padding(.top, 16)
                .transition(.opacity)
                .id(emotion)  // 切替で transition 発火

            // 吹き出し: ヒナの上部
            PeepBubbleView(emotion: emotion)
                .padding(.top, 2)
        }
        .frame(width: 128, height: 128)
        .help(tooltip)
        .animation(.easeInOut(duration: 0.25), value: emotion)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}
