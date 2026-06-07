import SwiftUI

/// 1 セッションのマスコットを描画する:
/// - 上端: PeepBubbleView (鳴き声バブル、1.5 秒間隔フラッシュ)
/// - 中央: AnimatedMascotView (Emotion ごとのドット絵フレームアニメ)
/// - 下端: (あれば) ミッションの吹き出し (SpeechBubble) → 識別ラベル (nickname または project_name)
///
/// 表示する creature 種は `session.mascotModel` から `MascotRegistry` で解決する
/// (未指定 / 未知 ID は既定の chick)。
///
/// クリック検出は MascotWindow 側 (5px 閾値で drag/click 区別)。ここはイベントを持たない。
///
/// `isOrphan = true` のときは terminal が消えている状態。
/// terminal app 再起動 / pane close 等ではグレースケール + 半透明で「迷子」感を出す。
struct MascotView: View {
    let session: SessionState
    var isOrphan: Bool = false

    @State private var now: Date = Date()

    private var model: MascotModel {
        MascotRegistry.model(id: session.mascotModel)
    }

    private var emotion: Emotion {
        EmotionEngine.emotion(for: session, now: now)
    }

    /// 一瞥して識別できるラベル: nickname > project_name (orphan なら先頭に "?")
    private var label: String {
        let base = (session.nickname?.isEmpty == false) ? session.nickname! : session.projectName
        return isOrphan ? "? \(base)" : base
    }

    private var tooltip: String {
        let name: String = {
            if let n = session.nickname, !n.isEmpty { return "\(n) (\(session.projectName))" }
            return session.projectName
        }()
        let elapsed = Int(now.timeIntervalSince(session.lastStateChangeAt))
        var lines = ["\(name)", "状態: \(session.state.rawValue) / \(elapsed)秒"]
        if let m = session.mission, !m.isEmpty {
            lines.insert("🎯 \(m)", at: 1)
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            // 中央: マスコット本体 (上下にラベル/バブルの余白を残す)
            AnimatedMascotView(model: model, emotion: emotion)
                .frame(width: 96, height: 96)
                .transition(.opacity)
                .id(emotion)

            // 左上: 鳴き声バブル (= 漫画のセリフが頭の上から左に出る感じ)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    PeepBubbleView(model: model, emotion: emotion)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .padding(.leading, 0)

            // 下端: (あれば) ミッションの吹き出し → その下に識別ラベル。
            // 吹き出しはしっぽが上＝マスコット側を向き、「マスコットのセリフ」として読める。
            VStack(spacing: 3) {
                Spacer()

                if let mission = session.mission, !mission.isEmpty {
                    // 長いミッションは横に伸ばさず折り返す (枠幅に収め、最大 3 行)。
                    Text("🎯 \(mission)")
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(Color.black.opacity(0.85))
                        // 上 padding はしっぽ高さ (7) ぶん余分に確保して本文がしっぽに被らないように
                        .padding(EdgeInsets(top: 11, leading: 9, bottom: 5, trailing: 9))
                        .background(
                            SpeechBubble()
                                .fill(Color.white.opacity(0.97))
                                .shadow(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 1)
                        )
                        .overlay(
                            SpeechBubble().stroke(Color.black.opacity(0.15), lineWidth: 0.8)
                        )
                        .frame(maxWidth: 122)
                }

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
        .frame(width: 128, height: 168)
        .saturation(isOrphan ? 0 : 1)
        .opacity(isOrphan ? 0.55 : 1)
        .help(tooltip)
        .animation(.easeInOut(duration: 0.25), value: emotion)
        .animation(.easeInOut(duration: 0.4), value: isOrphan)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }
}
