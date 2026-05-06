import SwiftUI

/// 1 セッションのヒナを描画する (Phase 4):
/// - 上端: PeepBubbleView (鳴き声バブル、1.5 秒間隔フラッシュ)
/// - 中央: AnimatedChickView (Emotion ごとのドット絵フレームアニメ)
/// - 下端: ラベル (nickname または project_name)
///
/// クリック検出は ChickWindow 側 (5px 閾値で drag/click 区別)。ここはイベントを持たない。
struct ChickView: View {
    let session: SessionState

    @State private var now: Date = Date()

    private var emotion: Emotion {
        EmotionEngine.emotion(for: session, now: now)
    }

    /// 一瞥して識別できるラベル: nickname > project_name
    private var label: String {
        if let n = session.nickname, !n.isEmpty { return n }
        return session.projectName
    }

    private var tooltip: String {
        let name: String = {
            if let n = session.nickname, !n.isEmpty { return "\(n) (\(session.projectName))" }
            return session.projectName
        }()
        let elapsed = Int(now.timeIntervalSince(session.lastStateChangeAt))
        return "\(name)\n状態: \(session.state.rawValue) / \(elapsed)秒"
    }

    var body: some View {
        ZStack {
            // 中央: ヒナ本体 (上下にラベル/バブルの余白を残す)
            AnimatedChickView(emotion: emotion)
                .frame(width: 96, height: 96)
                .transition(.opacity)
                .id(emotion)

            // 左上: 鳴き声バブル (= 漫画のセリフが頭の上から左に出る感じ)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    PeepBubbleView(emotion: emotion)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.leading, 0)

            // 下端: 識別ラベル
            VStack(spacing: 0) {
                Spacer()
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.62))
                    )
                    .frame(maxWidth: 120)
            }
            .padding(.bottom, 2)
        }
        .frame(width: 128, height: 128)
        .help(tooltip)
        .animation(.easeInOut(duration: 0.25), value: emotion)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}
