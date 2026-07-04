import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreImage

@available(macOS 13.0, *)
public final class RegionRecorder: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let ciContext = CIContext()
    private let queue = DispatchQueue(label: "com.poof.recorder")
    private var lastPTS: CMTime?
    private var onFrame: ((CGImage, Double) -> Void)?
    private var fallbackFPS: Int = 15

    public override init() { super.init() }

    // MARK: Pure coordinate math (unit tested)

    public struct StreamRect: Equatable {
        public let sourceRect: CGRect
        public let outputSize: CGSize
    }

    public static func convert(globalRect: CGRect, screenFrame: CGRect,
                               scale: CGFloat) -> StreamRect {
        // AppKit global coords are bottom-left origin. SCK sourceRect is top-left,
        // in points, relative to the display.
        let localX = globalRect.minX - screenFrame.minX
        let localTopY = screenFrame.maxY - globalRect.maxY
        let sourceRect = CGRect(x: localX, y: localTopY,
                                width: globalRect.width, height: globalRect.height)

        var outW = globalRect.width * scale
        var outH = globalRect.height * scale
        if outW > CGFloat(Config.maxWidth) {
            let k = CGFloat(Config.maxWidth) / outW
            outW *= k
            outH *= k
        }
        return StreamRect(sourceRect: sourceRect,
                          outputSize: CGSize(width: outW.rounded(), height: outH.rounded()))
    }

    public static func makeStreamRect(globalRect: CGRect,
                                      screen: NSScreen) -> (sourceRect: CGRect, outputSize: CGSize) {
        let r = convert(globalRect: globalRect, screenFrame: screen.frame,
                        scale: screen.backingScaleFactor)
        return (r.sourceRect, r.outputSize)
    }

    // MARK: Display resolution

    public static func display(for screen: NSScreen, completion: @escaping (SCDisplay?) -> Void) {
        let targetID = (screen.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
            if let error { NSLog("Poof: SCShareableContent error: \(error)") }
            let match = content?.displays.first { $0.displayID == targetID }
            if match == nil { NSLog("Poof: no SCDisplay matched NSScreenNumber \(String(describing: targetID))") }
            DispatchQueue.main.async { completion(match) }
        }
    }

    // MARK: Capture

    public func start(display: SCDisplay, sourceRect: CGRect, outputSize: CGSize, fps: Int,
                      onFrame: @escaping (CGImage, Double) -> Void,
                      onError: @escaping (Error) -> Void) {
        self.onFrame = onFrame
        self.fallbackFPS = fps
        self.lastPTS = nil

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = sourceRect
        config.width = Int(outputSize.width)
        config.height = Int(outputSize.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 6

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        do {
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            stream.startCapture { error in if let error { onError(error) } }
            self.stream = stream
        } catch {
            onError(error)
        }
    }

    public func stop(completion: @escaping () -> Void) {
        guard let stream else { completion(); return }
        stream.stopCapture { _ in
            DispatchQueue.main.async { completion() }
        }
        self.stream = nil
    }

    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                       of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        // Only keep frames SCK marks as complete (skip idle/blank). Fail closed:
        // drop the frame unless the status is definitively .complete.
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let statusRaw = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRaw),
              status == .complete else {
            return
        }

        let pts = sampleBuffer.presentationTimeStamp
        let delay: Double
        if let last = lastPTS {
            delay = max((pts - last).seconds, 0.0)
        } else {
            delay = 1.0 / Double(fallbackFPS)
        }
        lastPTS = pts

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
        onFrame?(cgImage, delay)
    }
}
