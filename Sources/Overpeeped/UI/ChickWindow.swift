import AppKit

/// borderless / 透明 / floating な NSWindow。
///
/// クリックとドラッグを `dragThreshold` (5px, SPEC §6) で区別する:
/// - 5px 以下しか動かなかった → `onClick` 発火 (= GhosttyAdapter.focus)
/// - 5px を超えて動いた → `performDrag(with:)` でウィンドウ移動 → `onDragEnd` 発火 (= 位置永続化)
///
/// NSWindow.performDrag(with:) は modal: 呼び出すとマウスを離すまでブロックする。
/// そのため performDrag が return した直後を「ドラッグ完了」として扱う。
final class ChickWindow: NSWindow {
    var onClick: (() -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?

    private let dragThreshold: CGFloat = 5
    private var dragStart: NSPoint?
    private var didDrag = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragStart = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, !didDrag else { return }
        let cur = event.locationInWindow
        let dist = hypot(cur.x - start.x, cur.y - start.y)
        if dist > dragThreshold {
            didDrag = true
            performDrag(with: event)   // modal until mouseUp
            // performDrag が return = ドラッグ完了
            onDragEnd?(self.frame.origin)
            dragStart = nil
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStart = nil
            didDrag = false
        }
        // performDrag を呼んだ場合は OS が mouseUp を消費するので、ここに来るのはクリック扱いのみ
        if !didDrag {
            onClick?()
        }
    }
}
