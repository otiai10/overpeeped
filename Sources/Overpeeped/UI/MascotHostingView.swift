import AppKit
import SwiftUI

/// SwiftUI 内容を埋め込みつつ、自身の bounds 全体を pointingHand cursor rect として登録する NSHostingView。
///
/// `addCursorRect` 方式なので mouseEntered/Exited を手動で扱う必要がなく、
/// OS が rect の入退出に応じて勝手にカーソルを管理してくれる。
final class MascotHostingView<Content: View>: NSHostingView<Content> {
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
