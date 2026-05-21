import Foundation

/// アプリ終了時に "幽霊チック" — もう動いていない Claude セッションの取り残された
/// session JSON — を掃除する。
///
/// peep skill / Hooks はセッションの PID を記録しないため、生死は `lastActivityAt` の
/// 時間ヒューリスティックで判定する: `now - lastActivityAt` が ``staleThreshold`` を
/// 超えていたら stale とみなし、`~/.overpeeped/sessions/<mascot_uuid>.json` と
/// `index.json` の該当エントリを削除する。
///
/// 生きていて単にアイドルなだけのセッションを巻き込まないよう閾値は長めに取ってある。
/// なお Hooks は既存ファイルを更新するだけで再生成はしないので、誤って生存セッションを
/// 掃除した場合は当該セッションで `/peep` し直す必要がある (Claude セッション自体には影響しない)。
enum StaleSweeper {
    /// この時間 `lastActivityAt` が更新されていないセッションを stale とみなす。
    static let staleThreshold: TimeInterval = 24 * 60 * 60   // 24h

    /// `~/.overpeeped/index.json` — session_id → mascot_uuid の対応表。
    nonisolated static var defaultIndexURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".overpeeped/index.json")
    }

    /// stale な session JSON と index エントリを削除する。
    /// - Returns: 掃除した mascot_uuid の配列 (ログ・テスト用)。
    @discardableResult
    static func sweep(
        sessionsDir: URL = SessionStore.defaultSessionsDir,
        indexURL: URL = StaleSweeper.defaultIndexURL,
        threshold: TimeInterval = StaleSweeper.staleThreshold,
        now: Date = Date()
    ) -> [String] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var sweptUuids: [String] = []
        for url in urls where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let session = try? SessionState.decode(from: data) else { continue }
            let idle = now.timeIntervalSince(session.lastActivityAt)
            guard idle > threshold else { continue }
            do {
                try fm.removeItem(at: url)
                sweptUuids.append(session.mascotUuid)
                Log.sweep.info("swept stale chick mascot=\(session.mascotUuid.shortLogId) idle=\(Int(idle))s")
            } catch {
                Log.sweep.error("failed to remove \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !sweptUuids.isEmpty {
            pruneIndex(at: indexURL, removingMascotUuids: Set(sweptUuids))
        }
        return sweptUuids
    }

    /// `index.json` から、掃除した mascot_uuid を値に持つエントリを atomic に除去する。
    private static func pruneIndex(at indexURL: URL, removingMascotUuids removed: Set<String>) {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        let kept = index.filter { !removed.contains($0.value) }
        guard kept.count != index.count else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let out = try? encoder.encode(kept) else { return }

        // atomic write (tmp + rename) — PositionStore と同じ流儀
        let tmp = indexURL.appendingPathExtension("tmp")
        do {
            try out.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(indexURL, withItemAt: tmp)
            Log.sweep.info("pruned \(index.count - kept.count) index entry(ies)")
        } catch {
            Log.sweep.error("index prune failed: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tmp)
        }
    }
}
