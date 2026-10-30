#if os(macOS)
import CoreGraphics
import XCTest
@testable import SwiftTerm

final class CustomGlyphPixelSpanTests: XCTestCase {
    func testSpansTileTheFractionalGrid() {
        let cellWidthPx: CGFloat = 9.66
        var previousEnd = 0
        for column in 0..<200 {
            let span = customGlyphPixelSpan(column: column, columns: 1, cellWidthPx: cellWidthPx)
            XCTAssertEqual(span.x0, previousEnd, "gap or overlap before column \(column)")
            XCTAssertLessThanOrEqual(abs(CGFloat(span.x0) - CGFloat(column) * cellWidthPx), 0.5)
            previousEnd = span.x0 + span.width
        }
        let wide = customGlyphPixelSpan(column: 7, columns: 2, cellWidthPx: cellWidthPx)
        XCTAssertEqual(wide.x0 + wide.width,
                       customGlyphPixelSpan(column: 9, columns: 1, cellWidthPx: cellWidthPx).x0)
    }
}
#endif
