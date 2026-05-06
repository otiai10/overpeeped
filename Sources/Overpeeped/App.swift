import AppKit
import Combine
import SwiftUI

// Phase 3: 複数 chick 対応。
// SessionStore が ~/.overpeeped/sessions/*.json を監視し、
// ChickWindowManager が chick_uuid 単位で NSWindow ライフサイクルを管理する。

@main
enum OverpeepedMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // Dock に出さない
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SessionStore()
    private let manager = ChickWindowManager(positionStore: PositionStore())
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        cancellable = store.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.manager.update(sessions: sessions)
            }
    }
}
