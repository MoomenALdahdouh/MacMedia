import AppKit
import OpenGL.GL
import MacMediaCore

final class VideoView: NSView {
    let videoLayer: VideoLayer

    init(engine: MediaPlayerEngine) {
        self.videoLayer = VideoLayer(engine: engine)
        super.init(frame: .zero)
        wantsLayer = true
        layer = videoLayer
        videoLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        videoLayer.isAsynchronous = false
        videoLayer.backgroundColor = NSColor.black.cgColor
        videoLayer.zPosition = -1
        autoresizingMask = [.width, .height]
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        videoLayer.contentsScale = window?.backingScaleFactor ?? 2
        videoLayer.frame = bounds
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        videoLayer.contentsScale = window?.backingScaleFactor ?? 2
    }
}

final class VideoLayer: CAOpenGLLayer {
    private let engine: MediaPlayerEngine
    private var didCreateContext = false
    private var captureRequest: ((NSBitmapImageRep?) -> Void)?

    init(engine: MediaPlayerEngine) {
        self.engine = engine
        super.init()
        isOpaque = true
        isAsynchronous = false
        autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func captureBitmap() -> NSBitmapImageRep? {
        var image: NSBitmapImageRep?
        captureRequest = { image = $0 }
        display()
        captureRequest = nil
        return image
    }

    override func canDraw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) -> Bool {
        true
    }

    override func draw(inCGLContext ctx: CGLContextObj, pixelFormat pf: CGLPixelFormatObj, forLayerTime t: CFTimeInterval, displayTime ts: UnsafePointer<CVTimeStamp>?) {
        if !didCreateContext {
            didCreateContext = engine.createRenderContextIfNeeded()
        }
        var fbo: GLint = 0
        glGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &fbo)
        let scale = max(contentsScale, 1)
        let width = Int32((bounds.width * scale).rounded())
        let height = Int32((bounds.height * scale).rounded())
        glClearColor(0, 0, 0, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        if didCreateContext, width > 0, height > 0 {
            engine.render(fbo: fbo, width: width, height: height)
        }
        if let request = captureRequest {
            captureRequest = nil
            request(Self.readPixels(width: width, height: height))
        }
        glFlush()
    }

    private static func readPixels(width: Int32, height: Int32) -> NSBitmapImageRep? {
        guard width > 0, height > 0 else { return nil }
        let w = Int(width)
        let h = Int(height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        glPixelStorei(GLenum(GL_PACK_ALIGNMENT), 1)
        pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            glReadPixels(0, 0, width, height, GLenum(GL_BGRA), GLenum(GL_UNSIGNED_INT_8_8_8_8_REV), base)
        }
        guard let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [.thirtyTwoBitLittleEndian, .alphaFirst],
            bytesPerRow: w * 4,
            bitsPerPixel: 32
        ), let dest = image.bitmapData else {
            return nil
        }
        let rowBytes = w * 4
        pixels.withUnsafeBytes { src in
            guard let srcBase = src.baseAddress else { return }
            for y in 0..<h {
                let srcRow = srcBase.advanced(by: y * rowBytes)
                let dstRow = dest.advanced(by: (h - 1 - y) * rowBytes)
                UnsafeMutableRawPointer(dstRow).copyMemory(from: srcRow, byteCount: rowBytes)
            }
        }
        return image
    }

    override func copyCGLPixelFormat(forDisplayMask mask: UInt32) -> CGLPixelFormatObj {
        var attributes: [CGLPixelFormatAttribute] = [
            kCGLPFAAccelerated,
            kCGLPFADoubleBuffer,
            kCGLPFAColorSize, CGLPixelFormatAttribute(rawValue: 24),
            kCGLPFAAlphaSize, CGLPixelFormatAttribute(rawValue: 8),
            CGLPixelFormatAttribute(rawValue: 0)
        ]
        var pixelFormat: CGLPixelFormatObj?
        var count: GLint = 0
        CGLChoosePixelFormat(&attributes, &pixelFormat, &count)
        if pixelFormat == nil {
            var fallback: [CGLPixelFormatAttribute] = [
                kCGLPFAAccelerated,
                kCGLPFADoubleBuffer,
                CGLPixelFormatAttribute(rawValue: 0)
            ]
            CGLChoosePixelFormat(&fallback, &pixelFormat, &count)
        }
        return pixelFormat!
    }
}
