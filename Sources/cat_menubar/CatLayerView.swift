import AppKit
import QuartzCore

final class CatLayerView: NSView {
    private let frameLayer = CALayer()
    private var frameSets: [CatStyle: CatFrameSet] = [:]
    private var currentStyle: CatStyle = .classic
    private var currentSpeed: Float = Float(AppConfig.Animation.initialSpeed)
    private var currentSourceFrames: [CGImage] = []
    private var baseDuration: CFTimeInterval = 0.5

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        frameLayer.contentsGravity = .resizeAspect
        frameLayer.magnificationFilter = .linear
        frameLayer.minificationFilter = .trilinear
        layer?.addSublayer(frameLayer)

        if let classic = CatFrameLoader.loadClassic() { frameSets[.classic] = classic }
        if let ruslan = CatFrameLoader.loadRuslan() { frameSets[.ruslan] = ruslan }

        if frameSets[.classic] == nil, frameSets[.ruslan] != nil { currentStyle = .ruslan }
        installCurrentStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Let the enclosing NSStatusBarButton receive mouse events.
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frameLayer.frame = bounds
        CATransaction.commit()
    }


    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        frameLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        rebuildTintedAnimation(preservingSpeed: true)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuildTintedAnimation(preservingSpeed: true)
    }

    var availableStyles: Set<CatStyle> {
        Set(frameSets.keys)
    }

    var style: CatStyle { currentStyle }

    func setStyle(_ style: CatStyle) {
        guard frameSets[style] != nil, style != currentStyle else { return }
        currentStyle = style
        installCurrentStyle()
    }

    func setCPUSpeed(_ speed: Double) {
        let clamped = Float(min(AppConfig.Animation.maximumSpeed, max(AppConfig.Animation.minimumSpeed, speed)))
        guard clamped != currentSpeed else { return }
        setLayerSpeedPreservingPhase(clamped)
        currentSpeed = clamped
    }

    func pause() {
        let local = frameLayer.convertTime(CACurrentMediaTime(), from: nil)
        frameLayer.speed = 0
        frameLayer.timeOffset = local
        frameLayer.beginTime = 0
    }

    func resume() {
        guard frameLayer.speed == 0 else { return }
        let pausedLocal = frameLayer.timeOffset
        let parentNow = parentTimeNow()
        frameLayer.speed = currentSpeed
        frameLayer.timeOffset = 0
        frameLayer.beginTime = parentNow - pausedLocal / CFTimeInterval(currentSpeed)
    }

    private func installCurrentStyle() {
        guard let set = frameSets[currentStyle] else { return }
        currentSourceFrames = set.frames
        baseDuration = set.baseDuration
        rebuildTintedAnimation(preservingSpeed: false)
    }

    private func rebuildTintedAnimation(preservingSpeed: Bool) {
        guard !currentSourceFrames.isEmpty else { return }
        let frames = currentSourceFrames.compactMap { tint($0) }
        guard !frames.isEmpty else { return }

        let oldSpeed = preservingSpeed ? currentSpeed : max(Float(AppConfig.Animation.minimumSpeed), currentSpeed)
        frameLayer.removeAnimation(forKey: "cat.frames")
        frameLayer.contents = frames[0]
        frameLayer.speed = 1
        frameLayer.timeOffset = 0
        frameLayer.beginTime = 0

        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames.map { $0 as Any }
        // Discrete keyframes need one terminal key time beyond the values.
        // The terminal 1.0 makes each source frame occupy one equal interval.
        let frameCount = Double(frames.count)
        animation.keyTimes = (0...frames.count).map {
            NSNumber(value: Double($0) / frameCount)
        }
        animation.calculationMode = .discrete
        animation.duration = baseDuration
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        frameLayer.add(animation, forKey: "cat.frames")

        currentSpeed = oldSpeed
        frameLayer.speed = oldSpeed
        frameLayer.timeOffset = 0
        frameLayer.beginTime = parentTimeNow()
    }

    private func setLayerSpeedPreservingPhase(_ newSpeed: Float) {
        let localTime = frameLayer.convertTime(CACurrentMediaTime(), from: nil)
        let parentNow = parentTimeNow()
        frameLayer.speed = newSpeed
        frameLayer.timeOffset = 0
        frameLayer.beginTime = parentNow - localTime / CFTimeInterval(newSpeed)
    }

    private func parentTimeNow() -> CFTimeInterval {
        if let parent = frameLayer.superlayer {
            return parent.convertTime(CACurrentMediaTime(), from: nil)
        }
        return CACurrentMediaTime()
    }

    private func tint(_ source: CGImage) -> CGImage? {
        let width = source.width
        let height = source.height
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.clear(rect)
        context.draw(source, in: rect)
        context.setBlendMode(.sourceIn)
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        context.setFillColor((dark ? NSColor.white : NSColor.black).cgColor)
        context.fill(rect)
        return context.makeImage()
    }
}
