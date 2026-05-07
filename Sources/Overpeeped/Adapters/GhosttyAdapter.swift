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
        // 成功時は "<winId>|<tabId>|<workingDir>" を return して Swift 側でパースしてログる
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
                  return (id of w as string) & "|" & (id of t as string) & "|" & (working directory of term)
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

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outStr = (String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if task.terminationStatus == 0 {
                // "winId|tabId|workingDir" をパース。dir に '|' を含む可能性があるので maxSplits=2
                let parts = outStr.split(separator: "|", maxSplits: 2, omittingEmptySubsequences: false).map(String.init)
                let winId = parts.indices.contains(0) ? parts[0] : "?"
                let tabId = parts.indices.contains(1) ? parts[1] : "?"
                let dir   = parts.indices.contains(2) ? parts[2] : "?"
                Log.focus.info("ok pane=\(short(terminalUUID)) win=\(winId) tab=\(tabId) dir=\(dir)")
                return true
            } else {
                let errStr = (String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "(unknown)")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                Log.focus.error("FAIL pane=\(short(terminalUUID)) status=\(task.terminationStatus) err=\(errStr)")
                return false
            }
        } catch {
            Log.focus.error("osascript launch failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func short(_ id: String) -> String {
        String(id.prefix(8))
    }

    /// 現在 Ghostty に存在するすべての terminal id を返す。
    /// Ghostty が起動していない / AppleScript 不許可 等で失敗したら nil。
    /// orphan 検出に使う。
    static func allTerminalIds() -> Set<String>? {
        let script = """
        tell application "Ghostty"
          set acc to ""
          repeat with w in windows
            repeat with t in tabs of w
              repeat with term in terminals of t
                set acc to acc & (id of term as string) & "\n"
              end repeat
            end repeat
          end repeat
          return acc
        end tell
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        let outPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let raw = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let ids = raw.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).map { String($0) }
            return Set(ids.filter { !$0.isEmpty })
        } catch {
            return nil
        }
    }
}
