import Foundation

/// Ghostty AppleScript の wrapper。Phase 0 で Phase0Demo に書いていた focus ロジックを切り出した。
///
/// ## API モデル (Ghostty 1.3+)
/// - `application > windows > tabs > terminals` の階層
/// - `select tab t` で tab 切り替え
/// - `focus term` で pane 選択 + window 前面化 (ただし tab 切り替えはしない)
///
/// なので両方を呼ぶ必要がある。詳細は LESSONS.md Phase 0 を参照。
enum GhosttyAdapter {
    @discardableResult
    static func focus(terminalUUID: String) -> Bool {
        let script = """
        tell application "Ghostty"
          activate
          set targetID to "\(terminalUUID)"
          repeat with w in windows
            repeat with t in tabs of w
              repeat with term in terminals of t
                if id of term is targetID then
                  select tab t
                  focus term
                  return "ok"
                end if
              end repeat
            end repeat
          end repeat
          error "overpeeped: terminal not found id=" & targetID number 1001
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]

        let errPipe = Pipe()
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                let msg = String(data: data, encoding: .utf8) ?? "(unknown)"
                NSLog("[overpeeped] focus failed (status=\(task.terminationStatus)): \(msg)")
                return false
            }
            return true
        } catch {
            NSLog("[overpeeped] osascript launch failed: \(error)")
            return false
        }
    }
}
