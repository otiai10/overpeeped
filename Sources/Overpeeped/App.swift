import AppKit
import Combine
import SwiftUI

// Phase 3: 複数マスコット対応。
// SessionStore が ~/.overpeeped/sessions/*.json を監視し、
// MascotWindowManager が mascot_uuid 単位で NSWindow ライフサイクルを管理する。

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
    private let manager = MascotWindowManager(positionStore: PositionStore())
    private var menuBar: MenuBarController?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()
        // メニューバーアイコン (NSStatusItem) は SessionStore を直接購読するので
        // ここでセットアップしておけばあとは自動で更新される
        menuBar = MenuBarController(store: store, manager: manager)
        cancellable = store.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.manager.update(sessions: sessions)
            }
    }
}
