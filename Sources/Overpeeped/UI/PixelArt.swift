import SwiftUI

/// ASCII テキストでドット絵を表現する 2D Color grid。
///
/// `.` または ` ` (空白) は透明。それ以外の文字は `palette` で Color に解決する。
/// 行ごとに `\n` で区切る。
struct PixelArt {
    let cells: [[Character]]      // [row][col]
    let palette: [Character: Color]

    var height: Int { cells.count }
    var width: Int { cells.first?.count ?? 0 }

    init(_ ascii: String, palette: [Character: Color]) {
        // 先頭末尾の空行を除き、行ごとに分割
        let trimmed = ascii.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false)
        self.cells = lines.map { Array($0) }
        self.palette = palette
    }

    func color(row: Int, col: Int) -> Color? {
        guard row >= 0, row < cells.count else { return nil }
        let line = cells[row]
        guard col >= 0, col < line.count else { return nil }
        let ch = line[col]
        if ch == "." || ch == " " { return nil }
        return palette[ch]
    }
}

/// PixelArt をフレームを保ったまま枠サイズに均等にスケールして描画する。
///
/// - 整数倍に近いサイズにすればドット感が綺麗に出る (アンチエイリアスで滲まないよう Path に半端を寄せる)
struct PixelArtView: View {
    let art: PixelArt

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard art.width > 0, art.height > 0 else { return }
                let cellW = size.width / CGFloat(art.width)
                let cellH = size.height / CGFloat(art.height)
                for r in 0..<art.height {
                    for c in 0..<art.width {
                        guard let color = art.color(row: r, col: c) else { continue }
                        // セル境界を 1px 重ねて隙間を防ぐ
                        let x = CGFloat(c) * cellW
                        let y = CGFloat(r) * cellH
                        let rect = CGRect(
                            x: floor(x),
                            y: floor(y),
                            width: ceil(cellW + 0.5),
                            height: ceil(cellH + 0.5)
                        )
                        ctx.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
