import Foundation
import os

/// アプリ共通の Logger 設定。
/// `NSLog` を使うと `Overpeeped[PID:TID]` の prefix が自動で付いて冗長なので、
/// macOS 標準の構造化ログ (os.Logger) を使う。
///
/// Console.app から subsystem `io.otiai10.overpeeped` でフィルタ可能。
/// `swift run` 中はターミナルにも出力される (category 名がプリフィックスにくる)。
enum Log {
    private static let subsystem = "io.otiai10.overpeeped"

    static let click    = Logger(subsystem: subsystem, category: "click")
    static let focus    = Logger(subsystem: subsystem, category: "focus")
    static let drag     = Logger(subsystem: subsystem, category: "drag")
    static let store    = Logger(subsystem: subsystem, category: "store")
    static let watcher  = Logger(subsystem: subsystem, category: "watcher")
    static let position = Logger(subsystem: subsystem, category: "position")
}
