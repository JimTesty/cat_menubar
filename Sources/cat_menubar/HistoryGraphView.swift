import AppKit

final class HistoryGraphView: NSView {
    private struct Sample {
        let timestamp: TimeInterval
        let cpu: CGFloat
        let gpu: CGFloat?
    }

    private var samples: [Sample] = []

    override var isFlipped: Bool { true }

    func append(cpu: Double, gpu: Double?, at timestamp: TimeInterval) {
        guard samples.last?.timestamp != timestamp else { return }

        samples.append(
            Sample(
                timestamp: timestamp,
                cpu: CGFloat(cpu),
                gpu: gpu.map { CGFloat($0) }
            )
        )

        while let first = samples.first,
              timestamp - first.timestamp > AppConfig.History.duration {
            samples.removeFirst()
        }
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let plotRect = bounds.insetBy(dx: 4, dy: 5)
        guard plotRect.width > 0, plotRect.height > 0 else { return }

        drawGuides(in: plotRect)
        drawLegend(in: plotRect)

        drawCurve(cpu: true, in: plotRect)
        drawCurve(cpu: false, in: plotRect)
    }

    private func drawGuides(in rect: NSRect) {
        let path = NSBezierPath()
        path.lineWidth = 0.75
        guideColor.setStroke()

        for fraction in stride(from: CGFloat(0), through: CGFloat(1), by: CGFloat(0.25)) {
            let y = rect.maxY - rect.height * fraction
            path.move(to: NSPoint(x: rect.minX, y: y))
            path.line(to: NSPoint(x: rect.maxX, y: y))
        }
        path.stroke()
    }

    private func drawLegend(in rect: NSRect) {
        let font = NSFont.systemFont(ofSize: 9, weight: .medium)
        let y = rect.minY - 1
        let cpuText = NSAttributedString(
            string: "CPU",
            attributes: [.font: font, .foregroundColor: cpuColor]
        )
        let gpuText = NSAttributedString(
            string: "GPU",
            attributes: [.font: font, .foregroundColor: gpuColor]
        )
        let cpuWidth = cpuText.size().width
        let gpuWidth = gpuText.size().width
        let gap: CGFloat = 8
        let totalWidth = cpuWidth + gpuWidth + gap
        let startX = rect.maxX - totalWidth

        cpuText.draw(at: NSPoint(x: startX, y: y))
        gpuText.draw(at: NSPoint(x: startX + cpuWidth + gap, y: y))
    }

    private func drawCurve(cpu: Bool, in rect: NSRect) {
        guard let latestTimestamp = samples.last?.timestamp else { return }

        let path = NSBezierPath()
        path.lineWidth = cpu ? AppConfig.History.cpuLineWidth : AppConfig.History.lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        var hasPoint = false
        var previousTimestamp: TimeInterval?
        var invalidXs: [CGFloat] = []
        for sample in samples {
            let value = cpu ? sample.cpu : sample.gpu
            let gap = previousTimestamp.map { sample.timestamp - $0 } ?? 0
            previousTimestamp = sample.timestamp

            guard let value = value else {
                hasPoint = false
                continue
            }
            let age = latestTimestamp - sample.timestamp
            let x = rect.maxX - rect.width * CGFloat(age / AppConfig.History.duration)
            guard value.isFinite else {
                hasPoint = false
                invalidXs.append(x)
                continue
            }
            if gap > AppConfig.History.maximumGap {
                hasPoint = false
            }

            let y = rect.maxY - rect.height * value
            let point = NSPoint(x: x, y: y)
            if hasPoint {
                path.line(to: point)
            } else {
                path.move(to: point)
                hasPoint = true
            }
        }

        (cpu ? cpuColor : gpuColor).setStroke()
        path.stroke()

        drawInvalidMarkers(at: invalidXs, in: rect)
    }

    private var isDarkAppearance: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private var cpuColor: NSColor {
        if isDarkAppearance {
            return NSColor(calibratedRed: 0.32, green: 0.70, blue: 1.0, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.0, green: 0.36, blue: 0.86, alpha: 1.0)
    }

    private var guideColor: NSColor {
        if isDarkAppearance {
            return NSColor.white.withAlphaComponent(0.20)
        }
        return NSColor.black.withAlphaComponent(0.14)
    }

    private var gpuColor: NSColor {
        if isDarkAppearance {
            return NSColor(calibratedRed: 0.70, green: 0.78, blue: 0.18, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.48, green: 0.56, blue: 0.04, alpha: 1.0)
    }

    private func drawInvalidMarkers(at xs: [CGFloat], in rect: NSRect) {
        guard !xs.isEmpty else { return }

        NSColor.systemRed.setFill()
        for x in xs {
            let marker = NSBezierPath(ovalIn: NSRect(
                x: x - 2.5,
                y: rect.minY + 2,
                width: 5,
                height: 5
            ))
            marker.fill()
        }
    }

}
