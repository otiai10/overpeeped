import AppKit
import Combine
import SwiftUI

// Phase 3: 複数マスコット対応。
// SessionStore が ~/.overpeeped/sessions/*.json を監視し、
// MascotWindowManager が mascot_uuid 単位で NSWindow ライフサイクルを管理する。

@main
enum OverpeepedMain {
    static func main() {
        // CLI: `overpeeped --quit` / `-q` — 起動中インスタンスを graceful に終了させて、
        // 自分自身は GUI を起動せずに抜ける (詳細は CommandLineQuit を参照)。
        let args = CommandLine.arguments.dropFirst()
        if args.contains("--quit") || args.contains("-q") {
            exit(CommandLineQuit.run())
        }

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

    /// graceful stop。⌘Q / メニュー / `overpeeped --quit` すべてここを通る
    /// (`NSRunningApplication.terminate()` の quit AppleEvent も同様)。
    ///
    /// 1. FileWatcher を明示停止し、マスコットウィンドウ・メニューバーアイコンを破棄
    /// 2. 幽霊チック (もう動いていない Claude セッションの session JSON) を掃除
    func applicationWillTerminate(_ notification: Notification) {
        store.stop()
        cancellable?.cancel()
        manager.shutdown()
        menuBar?.shutdown()

        let swept = StaleSweeper.sweep()
        if swept.isEmpty {
            Log.sweep.info("graceful stop — no stale chicks")
        } else {
            Log.sweep.info("graceful stop — swept \(swept.count) stale chick(s)")
        }
    }
}

/// `overpeeped --quit` / `-q` で呼ばれる、起動中の Overpeeped を graceful に終了させる処理。
///
/// 自分自身は `NSApplication` を起動せず、起動中インスタンスに `terminate()`
/// (quit AppleEvent) を送って、後始末 (`AppDelegate.applicationWillTerminate`) が
/// 走り切るのを待ってから抜ける。`forceTerminate` での即殺は応答しなかったときの最終手段。
enum CommandLineQuit {
    private static let bundleID = "io.otiai10.overpeeped"
    /// terminate を送ってからプロセス消滅を待つ上限 (掃除に多少時間がかかる想定)。
    private static let waitTimeout: TimeInterval = 10

    /// - Returns: プロセス終了コード (0 = 終了させた / 元から不在, 1 = 強制終了に至った)。
    static func run() -> Int32 {
        let myPid = ProcessInfo.processInfo.processIdentifier
        let targets = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPid }

        guard !targets.isEmpty else {
            print("overpeeped はもう起動していません。")
            return 0
        }

        // terminate() = quit AppleEvent → applicationWillTerminate を経由する graceful 終了。
        for app in targets { app.terminate() }

        let deadline = Date().addingTimeInterval(waitTimeout)
        while Date() < deadline {
            if targets.allSatisfy({ !isAlive(pid: $0.processIdentifier) }) { break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        let stragglers = targets.filter { isAlive(pid: $0.processIdentifier) }
        if stragglers.isEmpty {
            print("ぴよ... overpeeped を終了しました。")
            return 0
        }
        FileHandle.standardError.write(Data("overpeeped: 応答しないため強制終了します。\n".utf8))
        for app in stragglers { app.forceTerminate() }
        return 1
    }

    /// `kill(pid, 0)` で生存確認する (runloop 非依存。`NSRunningApplication.isTerminated`
    /// は通知駆動なので、event loop を回さないこのプロセスでは更新されないことがある)。
    private static func isAlive(pid: pid_t) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
