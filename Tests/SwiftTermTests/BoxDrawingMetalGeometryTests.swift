#if os(macOS) && canImport(MetalKit)
import AppKit
import Metal
import Testing
@testable import SwiftTerm

@MainActor
@Suite(.serialized)
struct BoxDrawingMetalGeometryTests {
    nonisolated static var metalIsUsable: Bool {
        MetalTerminalRenderer.shaderLibraryIsAvailable
    }

    @Test func pixelSpansTileTheFractionalGrid() {
        let cellWidthPx: CGFloat = 9.66
        var previousEnd = 0
        for column in 0..<200 {
            let span = customGlyphPixelSpan(column: column, columns: 1, cellWidthPx: cellWidthPx)
            #expect(span.x0 == previousEnd, "gap or overlap before column \(column)")
            #expect(abs(CGFloat(span.x0) - CGFloat(column) * cellWidthPx) <= 0.5)
            previousEnd = span.x0 + span.width
        }
        let wide = customGlyphPixelSpan(column: 7, columns: 2, cellWidthPx: cellWidthPx)
        #expect(wide.x0 + wide.width == customGlyphPixelSpan(column: 9, columns: 1, cellWidthPx: cellWidthPx).x0)
    }

    /// A render scale other than the one the cell width was snapped to — what
    /// a host that magnifies the terminal sets — makes the cell width
    /// fractional in device pixels. Box drawings must stay on the grid the
    /// text uses instead of stepping by the rounded width.
    @Test(.enabled(if: metalIsUsable))
    func boxDrawingsFollowTheTextGridAtAFractionalScale() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        let scale: CGFloat = 1.38
        let frame = CGRect(x: 0, y: 0, width: 1000, height: 120)
        let view = TerminalView(frame: frame)
        view.frameDriver.invalidate()
        view.metalScaleFactorOverride = scale
        let cellWidthPx = view.cellDimension.width * scale
        let columns = Array(stride(from: 0, to: min(view.terminal.cols, 120), by: 2))
        let lastColumn = try #require(columns.last)
        // Without this the old rounded step would land on the same pixels.
        try #require(abs(CGFloat(lastColumn) * (cellWidthPx.rounded() - cellWidthPx)) > 1)
        view.feed(text: String(repeating: "\u{2502} ", count: columns.count))
        let target = TerminalMetalLayerView(frame: frame)
        target.renderDevice = device
        target.renderContentsScale = scale
        target.renderDrawableSize = CGSize(width: frame.width * scale, height: frame.height * scale)
        let renderer = try MetalTerminalRenderer(target: target)
        renderer.waitForCompletionAfterCommit = true
        renderer.capturesDrawData = true
        #expect(view.renderSnapshotForMetal(renderer: renderer, target: target))
        let drawData = try #require(renderer.lastDrawData)
        let row = try #require(drawData.rows.first { $0.glyphGrayCount > 0 })
        let buffer = try #require(row.glyphGrayBuffer)
        let cells = UnsafeBufferPointer(start: buffer.contents().assumingMemoryBound(to: TextCell.self),
                                        count: row.glyphGrayCount)
        let xs = cells.map(\.position.x).sorted()
        try #require(xs.count == columns.count)
        for (x, column) in zip(xs, columns) {
            let expected = customGlyphPixelSpan(column: column, columns: 1, cellWidthPx: cellWidthPx)
            #expect(x == Float(expected.x0), "column \(column)")
        }
    }
}
#endif
