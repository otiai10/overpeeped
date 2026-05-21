import Foundation
import Combine

/// `~/.overpeeped/sessions/` 配下の JSON 群を真実の源として
/// `[mascot_uuid: SessionState]` を ObservableObject で公開する。
///
/// - FileWatcher がディレクトリ変更を通知 → reload() で全ファイル読み直し
/// - JSON が壊れているファイルはスキップ (失敗で全体停止しない)
/// - メインスレッドで sessions を更新するので SwiftUI から直接 bind できる
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    private let sessionsDir: URL
    private var watcher: FileWatcher?

    init(sessionsDir: URL = SessionStore.defaultSessionsDir) {
        self.sessionsDir = sessionsDir
    }

    nonisolated static var defaultSessionsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".overpeeped/sessions", isDirectory: true)
    }

    func start() {
        // ディレクトリが無いと watcher が動かないので作っておく (skill 未実行で起動された場合の保険)
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        let w = FileWatcher(url: sessionsDir) { [weak self] in
            Task { @MainActor [weak self] in self?.reload() }
        }
        w.start()
        watcher = w
    }

    func stop() {
        watcher?.stop()
        watcher = nil
    }

    func reload() {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            sessions = []
            return
        }
        let jsonFiles = urls.filter { $0.pathExtension == "json" }
        var loaded: [SessionState] = []
        for url in jsonFiles {
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                let s = try SessionState.decode(from: data)
                loaded.append(s)
            } catch {
                Log.store.error("decode failed for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        // mascot_uuid 順で安定化
        loaded.sort { $0.mascotUuid < $1.mascotUuid }
        sessions = loaded
    }
}
