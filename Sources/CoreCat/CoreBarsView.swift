import AppKit

final class CoreBarsView: NSView {
    var values: [Double] = [] {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !values.isEmpty else { return }

        let columns = values.count > 4 ? 2 : 1
        let rows = Int(ceil(Double(values.count) / Double(columns)))
        let columnWidth = bounds.width / CGFloat(columns)
        let rowHeight = max(20, min(26, bounds.height / CGFloat(max(1, rows))))
        let labelWidth: CGFloat = 56
        let percentWidth: CGFloat = 44
        let padding: CGFloat = 6

        for i in 0..<values.count {
            let column = i / rows
            let row = i % rows
            let x = CGFloat(column) * columnWidth
            let y = CGFloat(row) * rowHeight
            let usage = min(1, max(0, values[i]))

            let labelRect = NSRect(x: x, y: y + 3, width: labelWidth, height: rowHeight - 4)
            let text = "Core \(i)"
            text.draw(in: labelRect, withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ])

            let barX = x + labelWidth
            let barWidth = max(12, columnWidth - labelWidth - percentWidth - padding * 2)
            let barRect = NSRect(x: barX, y: y + 6, width: barWidth, height: 8)
            let background = NSBezierPath(roundedRect: barRect, xRadius: 3, yRadius: 3)
            NSColor.quaternaryLabelColor.setFill()
            background.fill()

            let usedRect = NSRect(x: barX, y: y + 6, width: barWidth * CGFloat(usage), height: 8)
            if usedRect.width > 0.5 {
                let used = NSBezierPath(roundedRect: usedRect, xRadius: 3, yRadius: 3)
                NSColor.controlAccentColor.setFill()
                used.fill()
            }

            let pctRect = NSRect(x: barX + barWidth + padding, y: y + 3, width: percentWidth, height: rowHeight - 4)
            String(format: "%3.0f%%", usage * 100).draw(in: pctRect, withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ])
        }
    }
}
