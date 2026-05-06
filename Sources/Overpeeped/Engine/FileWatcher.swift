import Foundation

/// `DispatchSource.makeFileSystemObjectSource` を使ってディレクトリ変更を監視する薄いラッパー。
///
/// - 監視対象: ディレクトリ
/// - イベント: `.write` (子ファイルの追加/削除/書き換え)
/// - 通知: 変更があったら `onChange` がメインスレッドで呼ばれる
/// - スロットル: 連続イベントを 100ms に集約 (atomic mv で複数イベントが立て続けに来るため)
///
/// SPEC §3 / §10 に基づく FileWatcher の実装。
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var fd: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "overpeeped.filewatcher")
    private var pendingWorkItem: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard source == nil else { return }
        let path = (url.path as NSString).fileSystemRepresentation
        fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            NSLog("[overpeeped] FileWatcher: open() failed for \(url.path) errno=\(errno)")
            return
        }
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: queue
        )
        s.setEventHandler { [weak self] in
            self?.scheduleFire()
        }
        s.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fd >= 0 {
                close(self.fd)
                self.fd = -1
            }
        }
        s.resume()
        source = s

        // 初期同期 — 起動時に既にあるファイルを反映するため
        DispatchQueue.main.async { [weak self] in self?.onChange() }
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    /// 連続イベントを 100ms に集約して main で発火。
    private func scheduleFire() {
        pendingWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        pendingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100), execute: item)
    }
}
