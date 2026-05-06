import AppKit
import Foundation

/// `~/.overpeeped/positions.json` でドラッグ位置を永続化する。
///
/// JSON スキーマ:
/// ```json
/// { "<chick_uuid>": {"x": 1.0, "y": 2.0}, ... }
/// ```
///
/// SPEC §6: 「ユーザーがドラッグ移動した位置は positions.json に永続化」
@MainActor
final class PositionStore {
    private let url: URL
    private var positions: [String: CGPoint] = [:]

    init(url: URL = PositionStore.defaultURL) {
        self.url = url
        load()
    }

    nonisolated static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".overpeeped/positions.json")
    }

    func position(for chickUuid: String) -> CGPoint? {
        positions[chickUuid]
    }

    func save(position: CGPoint, for chickUuid: String) {
        positions[chickUuid] = position
        persist()
    }

    func remove(chickUuid: String) {
        positions.removeValue(forKey: chickUuid)
        persist()
    }

    // MARK: - Private

    private struct PointDTO: Codable {
        let x: Double
        let y: Double
    }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: PointDTO].self, from: data)
        else {
            positions = [:]
            return
        }
        positions = dict.mapValues { CGPoint(x: $0.x, y: $0.y) }
    }

    private func persist() {
        let dict = positions.mapValues { PointDTO(x: $0.x, y: $0.y) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(dict) else { return }

        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // atomic write (tmp + rename)
        let tmp = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            Log.position.error("persist failed: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tmp)
        }
    }
}
