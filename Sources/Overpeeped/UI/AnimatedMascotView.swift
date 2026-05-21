import SwiftUI

/// `MascotModel` から `Emotion` ごとのフレーム配列を引き、`TimelineView` で時刻ベースに切り替える。
///
/// 時刻ベースで frame index を計算するので、Emotion を切り替えても reset 処理は不要
/// (= 自動的に新 Emotion の frames へ切り替わる)。
struct AnimatedMascotView: View {
    let model: MascotModel
    let emotion: Emotion

    var body: some View {
        let frames = model.frames(for: emotion)
        let interval = max(model.frameDuration(for: emotion), 0.05)

        TimelineView(.periodic(from: .now, by: interval)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let idx = Int(elapsed / interval) % max(1, frames.count)
            if let art = frames.indices.contains(idx) ? frames[idx] : frames.first {
                PixelArtView(art: art)
            }
        }
    }
}
