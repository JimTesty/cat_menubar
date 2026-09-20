import AppKit

final class StatsViewController: NSViewController {
    private let cpuLabel = NSTextField(labelWithString: "CPU  --")
    private let historyGraph = HistoryGraphView(frame: .zero)
    private let coreBars = CoreBarsView(frame: .zero)
    private let gpuLabel = NSTextField(labelWithString: "GPU  N/A")
    private let memoryPressureLabel = NSTextField(labelWithString: "Pressure  --")
    private let memoryLabel = NSTextField(labelWithString: "RAM  --")
    private let compressedLabel = NSTextField(labelWithString: "Compressed  --")
    private let swapLabel = NSTextField(labelWithString: "Swap  --")
    private var coreHeightConstraint: NSLayoutConstraint?

    override func loadView() {
        let root = NSView(frame: NSRect(origin: .zero, size: AppConfig.Popover.size))
        self.view = root

        cpuLabel.font = NSFont.monospacedDigitSystemFont(ofSize: AppConfig.Typography.cpuSize, weight: .semibold)
        cpuLabel.textColor = .labelColor

        let cpuHeader = NSView()
        cpuHeader.translatesAutoresizingMaskIntoConstraints = false
        cpuHeader.addSubview(cpuLabel)
        cpuHeader.addSubview(historyGraph)
        cpuLabel.translatesAutoresizingMaskIntoConstraints = false
        historyGraph.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cpuHeader.heightAnchor.constraint(equalToConstant: AppConfig.History.graphHeight),
            cpuLabel.leadingAnchor.constraint(equalTo: cpuHeader.leadingAnchor),
            cpuLabel.topAnchor.constraint(equalTo: cpuHeader.topAnchor),
            historyGraph.leadingAnchor.constraint(equalTo: cpuLabel.trailingAnchor, constant: 8),
            historyGraph.trailingAnchor.constraint(equalTo: cpuHeader.trailingAnchor),
            historyGraph.topAnchor.constraint(equalTo: cpuHeader.topAnchor),
            historyGraph.bottomAnchor.constraint(equalTo: cpuHeader.bottomAnchor)
        ])

        let coresTitle = sectionLabel("Logical cores")
        let gpuTitle = sectionLabel("GPU")
        let memoryTitle = sectionLabel("Memory")

        for label in [memoryPressureLabel, memoryLabel, compressedLabel, swapLabel] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: AppConfig.Typography.metricSize, weight: .regular)
            label.textColor = .labelColor
        }
        gpuLabel.font = NSFont.monospacedDigitSystemFont(ofSize: AppConfig.Typography.metricSize, weight: .regular)

        let gpuNote = NSTextField(wrappingLabelWithString: "Apple Silicon AGX driver counter; best-effort, no sudo.")
        gpuNote.font = NSFont.systemFont(ofSize: AppConfig.Typography.noteSize)
        gpuNote.textColor = .tertiaryLabelColor

        let divider1 = divider()
        let divider2 = divider()

        let stack = NSStackView(views: [
            cpuHeader,
            coresTitle,
            coreBars,
            divider1,
            gpuTitle,
            gpuLabel,
            gpuNote,
            divider2,
            memoryTitle,
            memoryPressureLabel,
            memoryLabel,
            compressedLabel,
            swapLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = AppConfig.Popover.stackSpacing
        stack.setCustomSpacing(
            AppConfig.Popover.cpuLabelAreaHeight
                + AppConfig.Popover.cpuToCoresSpacing
                - AppConfig.History.graphHeight,
            after: cpuHeader
        )
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        coreBars.translatesAutoresizingMaskIntoConstraints = false
        coreHeightConstraint = coreBars.heightAnchor.constraint(equalToConstant: AppConfig.Popover.coreBarsHeight)
        coreHeightConstraint?.isActive = true

        for item in [cpuHeader, coreBars, divider1, divider2, gpuNote] {
            item.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: AppConfig.Popover.horizontalInset),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -AppConfig.Popover.horizontalInset),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: AppConfig.Popover.topInset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -AppConfig.Popover.bottomInset)
        ])
    }

    func recordHistory(_ snapshot: SystemSnapshot, at timestamp: TimeInterval) {
        historyGraph.append(cpu: snapshot.cpu.total, gpu: snapshot.gpu?.utilization, at: timestamp)
    }

    func update(_ snapshot: SystemSnapshot) {
        cpuLabel.stringValue = "CPU\(percentField(snapshot.cpu.total * 100))%"
        coreBars.values = snapshot.cpu.cores
        let rows = Int(ceil(Double(max(1, snapshot.cpu.cores.count)) / Double(snapshot.cpu.cores.count > 4 ? 2 : 1)))
        coreHeightConstraint?.constant = CGFloat(rows) * AppConfig.Popover.coreRowHeight

        if let gpu = snapshot.gpu, let value = gpu.utilization {
            if let mapped = gpu.inUseSystemMemoryBytes {
                gpuLabel.stringValue = String(
                    format: "GPU%@%%  ·  mapped %.2f GiB",
                    percentField(value * 100), gib(mapped)
                )
            } else {
                gpuLabel.stringValue = "GPU\(percentField(value * 100))%"
            }
        } else {
            gpuLabel.stringValue = "GPU N/A"
        }

        if let memory = snapshot.memory, memory.totalBytes > 0 {
            let percent = memory.totalBytes > 0 ? Double(memory.usedBytes) / Double(memory.totalBytes) * 100 : 0
            memoryPressureLabel.stringValue = "Pressure  \(memory.pressure.rawValue)"
            memoryLabel.stringValue = String(
                format: "RAM  %.2f / %.2f GiB  (%4.1f%%)",
                gib(memory.usedBytes), gib(memory.totalBytes), percent
            )
            compressedLabel.stringValue = String(
                format: "Compressed  %.2f GiB",
                gib(memory.compressedBytes)
            )
            if memory.swapTotalBytes > 0 {
                let swapText = String(
                    format: "Swap  %.2f / %.2f GiB",
                    gib(memory.swapUsedBytes), gib(memory.swapTotalBytes)
                )
                swapLabel.stringValue = swapTextWithDisk(swapText, memory: memory)
            } else {
                swapLabel.stringValue = swapTextWithDisk("Swap  0 GiB", memory: memory)
            }
        }
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = NSFont.systemFont(ofSize: AppConfig.Typography.sectionSize, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func gib(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }

    private func percentField(_ value: Double) -> String {
        // This FIGURE SPACE (U+2007) hack is for making the padding space as wide as a digit
        String(format: "%5.1f", value)
            .replacingOccurrences(of: " ", with: "\u{2007}")
    }

    private func swapTextWithDisk(_ swapText: String, memory: MemorySnapshot) -> String {
        guard let freeBytes = memory.diskFreeBytes else { return swapText }
        return String(format: "%@  (disk %.2f GiB free)", swapText, gib(freeBytes))
    }
}
