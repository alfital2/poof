import XCTest
import AppKit
@testable import PoofCore

final class RegionRecorderTests: XCTestCase {
    // A synthetic screen-like frame: 1440x900 at origin (0,0), scale 2.
    func testMakeStreamRectConvertsToTopLeftLocal() {
        // We can't fabricate an NSScreen; test the pure math helper instead.
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let scale: CGFloat = 2
        // A 200x100 rect whose bottom-left is at (100, 700) in global coords.
        let global = CGRect(x: 100, y: 700, width: 200, height: 100)

        let result = RegionRecorder.convert(globalRect: global,
                                            screenFrame: screenFrame, scale: scale)
        // Top-left local: x unchanged (100). topY = maxY(900) - rect.maxY(800) = 100.
        XCTAssertEqual(result.sourceRect, CGRect(x: 100, y: 100, width: 200, height: 100))
        // Output width: 200pt * 2 = 400px, under maxWidth(900) -> stays 400x200.
        XCTAssertEqual(result.outputSize, CGSize(width: 400, height: 200))
    }

    func testOutputScaledDownWhenAboveMaxWidth() {
        let screenFrame = CGRect(x: 0, y: 0, width: 3000, height: 2000)
        let scale: CGFloat = 1
        let global = CGRect(x: 0, y: 0, width: 1800, height: 900)
        let result = RegionRecorder.convert(globalRect: global,
                                            screenFrame: screenFrame, scale: scale)
        // 1800px wide > 900 maxWidth -> scale to 900 wide, height 450.
        XCTAssertEqual(result.outputSize, CGSize(width: 900, height: 450))
    }
}
