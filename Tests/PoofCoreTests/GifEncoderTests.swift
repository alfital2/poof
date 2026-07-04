import XCTest
import CoreGraphics
import ImageIO
@testable import PoofCore

final class GifEncoderTests: XCTestCase {
    private func solidImage(gray: CGFloat, size: Int = 8) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(red: gray, green: gray, blue: gray, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return ctx.makeImage()!
    }

    func testEncodesTwoFramesWithGif89aHeader() throws {
        let encoder = try XCTUnwrap(GifEncoder())
        encoder.append(solidImage(gray: 0.1), delay: 0.1)
        encoder.append(solidImage(gray: 0.9), delay: 0.1)
        XCTAssertEqual(encoder.count, 2)

        let data = try XCTUnwrap(encoder.finalize())
        XCTAssertGreaterThan(data.count, 0)

        // GIF89a magic
        let header = String(bytes: data.prefix(6), encoding: .ascii)
        XCTAssertEqual(header, "GIF89a")

        // Decodes back to 2 frames
        let src = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        XCTAssertEqual(CGImageSourceGetCount(src), 2)
    }

    func testFinalizeReturnsNilWithNoFrames() {
        let encoder = GifEncoder()
        XCTAssertNil(encoder?.finalize())
    }
}
