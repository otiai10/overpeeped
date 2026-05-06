import SwiftUI

/// 1 セッションのヒナを描画する。
///
/// クリック検出は **NSWindow (ChickWindow) 側** で行う (drag/click を 5px 閾値で区別するため)。
/// したがってここでは onTapGesture を持たず、表示専用の View に徹する。
///
/// Phase 4 でドット絵 PNG とアニメーションに置き換える予定。
struct ChickView: View {
    let session: SessionState

    /// 1 秒ごとに `now` を更新して Emotion を再計算する (経過時間ベースの遷移を見るため)
    @State private var now: Date = Date()

    private var emotion: Emotion {
        EmotionEngine.emotion(for: session, now: now)
    }

    private var tooltip: String {
        let name = (session.nickname?.isEmpty == false ? "\(session.nickname!) (\(session.projectName))" : session.projectName)
        let elapsed = Int(now.timeIntervalSince(session.lastStateChangeAt))
        return "\(name)\n状態: \(session.state.rawValue) / \(elapsed)秒"
    }

    var body: some View {
        Text(emotion.emojiFallback)
            .font(.system(size: 96))
            .frame(width: 128, height: 128)
            .help(tooltip)
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
    }
}
