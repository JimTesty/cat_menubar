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
        let rowHeight = max(
            AppConfig.CoreBars.minimumRowHeight,
            min(AppConfig.CoreBars.maximumRowHeight, bounds.height / CGFloat(max(1, rows)))
        )
        let labelWidth = AppConfig.CoreBars.labelWidth
        let percentWidth = AppConfig.CoreBars.percentWidth
        let padding = AppConfig.CoreBars.padding

        for i in 0..<values.count {
            let column = i / rows
            let row = i % rows
            let x = CGFloat(column) * columnWidth
            let y = CGFloat(row) * rowHeight
            let usage = min(1, max(0, values[i]))

            let labelRect = NSRect(
                x: x,
                y: y + AppConfig.CoreBars.labelTopOffset,
                width: labelWidth,
                height: rowHeight - AppConfig.CoreBars.textBottomInset
            )
            let text = "Core \(i)"
            text.draw(in: labelRect, withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: AppConfig.Typography.coreSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ])

            let barX = x + labelWidth
            let barWidth = max(
                AppConfig.CoreBars.minimumBarWidth,
                columnWidth - labelWidth - percentWidth - padding * 2
            )
            let barRect = NSRect(
                x: barX,
                y: y + AppConfig.CoreBars.barTopOffset,
                width: barWidth,
                height: AppConfig.CoreBars.barHeight
            )
            let background = NSBezierPath(
                roundedRect: barRect,
                xRadius: AppConfig.CoreBars.barCornerRadius,
                yRadius: AppConfig.CoreBars.barCornerRadius
            )
            NSColor.quaternaryLabelColor.setFill()
            background.fill()

            let usedRect = NSRect(
                x: barX,
                y: y + AppConfig.CoreBars.barTopOffset,
                width: barWidth * CGFloat(usage),
                height: AppConfig.CoreBars.barHeight
            )
            if usedRect.width > AppConfig.CoreBars.minimumVisibleBarWidth {
                let used = NSBezierPath(
                    roundedRect: usedRect,
                    xRadius: AppConfig.CoreBars.barCornerRadius,
                    yRadius: AppConfig.CoreBars.barCornerRadius
                )
                NSColor.controlAccentColor.setFill()
                used.fill()
            }

            let pctRect = NSRect(
                x: barX + barWidth + padding,
                y: y + AppConfig.CoreBars.labelTopOffset,
                width: percentWidth,
                height: rowHeight - AppConfig.CoreBars.textBottomInset
            )
            String(format: "%3.0f%%", usage * 100).draw(in: pctRect, withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: AppConfig.Typography.coreSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ])
        }
    }
}
