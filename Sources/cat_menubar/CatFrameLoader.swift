import AppKit
import CoreGraphics
import Foundation

struct CatFrameSet {
    let frames: [CGImage]
    let baseDuration: CFTimeInterval
}

enum CatFrameLoader {
    static func loadClassic() -> CatFrameSet? {
        var frames = [CGImage]()
        for i in 0..<5 {
            guard let url = ResourceLocator.url(relativePath: "classic/cat\(i).png"),
                  let image = NSImage(contentsOf: url),
                  let cg = cgImage(from: image) else {
                return nil
            }
            guard let compact = resized(cg, to: CGSize(width: 56, height: 36)) else { return nil }
            frames.append(compact)
        }
        return CatFrameSet(frames: frames, baseDuration: 0.50)
    }

    static func loadRuslan() -> CatFrameSet? {
        guard let url = ResourceLocator.url(relativePath: "ruslan/cat-walking.json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        let frames = MiniLottieRenderer.renderCatFrames(data: data, pixelSize: CGSize(width: 64, height: 64))
        guard !frames.isEmpty else { return nil }
        // The source comp is 14 frames at 25 fps.
        return CatFrameSet(frames: frames, baseDuration: Double(frames.count) / 25.0)
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    private static func resized(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = max(1, Int(size.width.rounded()))
        let height = max(1, Int(size.height.rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return context.makeImage()
    }
}
