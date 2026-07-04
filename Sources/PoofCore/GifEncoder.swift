import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

public final class GifEncoder {
    private let data = NSMutableData()
    private let destination: CGImageDestination
    private var frameCount = 0

    public init?(loopForever: Bool = true) {
        guard let dest = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.gif.identifier as CFString, 100, nil
        ) else { return nil }
        destination = dest
        let gifProps: [CFString: Any] = [kCGImagePropertyGIFLoopCount: loopForever ? 0 : 1]
        CGImageDestinationSetProperties(
            dest, [kCGImagePropertyGIFDictionary: gifProps] as CFDictionary
        )
    }

    public func append(_ image: CGImage, delay: Double) {
        let safeDelay = max(delay, 0.02) // GIF viewers clamp very small delays
        let frameProps: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: safeDelay,
                kCGImagePropertyGIFUnclampedDelayTime: safeDelay,
            ] as [CFString: Any]
        ]
        CGImageDestinationAddImage(destination, image, frameProps as CFDictionary)
        frameCount += 1
    }

    public var count: Int { frameCount }

    public func finalize() -> Data? {
        guard frameCount > 0, CGImageDestinationFinalize(destination) else { return nil }
        var output = data as Data

        // Ensure GIF89a header for animated GIFs
        if output.count >= 6 {
            var bytes = [UInt8](output.prefix(6))
            if bytes[0] == 71 && bytes[1] == 73 && bytes[2] == 70 { // "GIF"
                if bytes[3] == 56 && bytes[4] == 55 { // "87"
                    bytes[3] = 56 // "8"
                    bytes[4] = 57 // "9"
                    let mutableOutput = NSMutableData(data: output)
                    mutableOutput.replaceBytes(in: NSRange(location: 0, length: 6), withBytes: bytes)
                    output = mutableOutput as Data
                }
            }
        }

        return output
    }
}
