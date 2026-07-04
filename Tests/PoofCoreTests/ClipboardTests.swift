import XCTest
import AppKit
@testable import PoofCore

final class ClipboardTests: XCTestCase {
    func testGifTypeIdentifier() {
        XCTAssertEqual(Clipboard.gifType.rawValue, "com.compuserve.gif")
    }

    func testCopyGIFRoundTrips() {
        let sample = Data([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) // "GIF89a"
        Clipboard.copyGIF(sample)
        let read = NSPasteboard.general.data(forType: Clipboard.gifType)
        XCTAssertEqual(read, sample)
    }
}
