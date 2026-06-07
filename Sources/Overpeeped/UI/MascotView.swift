import SwiftUI

/// 1 セッションのマスコットを描画する:
/// - 上端: PeepBubbleView (鳴き声バブル、1.5 秒間隔フラッシュ)
/// - 中央: AnimatedMascotView (Emotion ごとのドット絵フレームアニメ)
/// - 下端: ラベル (nickname または project_name)
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

            // 下端: 識別ラベル + (あれば) ミッションラベル
            VStack(spacing: 2) {
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

                if let mission = session.mission, !mission.isEmpty {
                    Text("🎯 \(mission)")
                        .font(.system(size: 8, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.72))
                        )
                        .frame(maxWidth: 124)
                }
            }
            .padding(.bottom, 2)
        }
        .frame(width: 128, height: 128)
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
