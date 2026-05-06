import SwiftUI

/// Emotion から ChickSprites のフレーム配列を引き、`TimelineView` で時刻ベースに切り替える。
///
/// 時刻ベースで frame index を計算するので、Emotion を切り替えても reset 処理は不要
/// (= 自動的に新 Emotion の frames へ切り替わる)。
struct AnimatedChickView: View {
    let emotion: Emotion

    var body: some View {
        let frames = ChickSprites.frames(for: emotion)
        let intervalMs = ChickSprites.frameDurationMs(for: emotion)
        let interval = TimeInterval(intervalMs) / 1000.0

        TimelineView(.periodic(from: .now, by: interval)) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            let idx = Int(elapsed / max(interval, 0.05)) % max(1, frames.count)
            let art = frames.indices.contains(idx) ? frames[idx] : (frames.first ?? ChickSprites.focused[0])
            PixelArtView(art: art)
        }
    }
}
