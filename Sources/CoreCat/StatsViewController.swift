import AppKit

final class StatsViewController: NSViewController {
    private let cpuLabel = NSTextField(labelWithString: "CPU  --")
    private let coreBars = CoreBarsView(frame: .zero)
    private let gpuLabel = NSTextField(labelWithString: "GPU  N/A")
    private let memoryLabel = NSTextField(labelWithString: "RAM  --")
    private let memoryDetailLabel = NSTextField(labelWithString: "Compressed --  ·  Swap --")
    private var coreHeightConstraint: NSLayoutConstraint?

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 370, height: 360))
        self.view = root

        cpuLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
        cpuLabel.textColor = .labelColor

        let coresTitle = sectionLabel("Logical cores")
        let gpuTitle = sectionLabel("GPU")
        let memoryTitle = sectionLabel("Memory")

        gpuLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        memoryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        memoryDetailLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        memoryDetailLabel.textColor = .secondaryLabelColor

        let gpuNote = NSTextField(wrappingLabelWithString: "Apple Silicon AGX driver counter; best-effort, no sudo.")
        gpuNote.font = NSFont.systemFont(ofSize: 10)
        gpuNote.textColor = .tertiaryLabelColor

        let divider1 = divider()
        let divider2 = divider()

        let stack = NSStackView(views: [
            cpuLabel,
            coresTitle,
            coreBars,
            divider1,
            gpuTitle,
            gpuLabel,
            gpuNote,
            divider2,
            memoryTitle,
            memoryLabel,
            memoryDetailLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        coreBars.translatesAutoresizingMaskIntoConstraints = false
        coreHeightConstraint = coreBars.heightAnchor.constraint(equalToConstant: 104)
        coreHeightConstraint?.isActive = true

        for item in [coreBars, divider1, divider2, gpuNote] {
            item.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -12)
        ])
    }

    func update(_ snapshot: SystemSnapshot) {
        cpuLabel.stringValue = String(format: "CPU  %5.1f%%", snapshot.cpu.total * 100)
        coreBars.values = snapshot.cpu.cores
        let rows = Int(ceil(Double(max(1, snapshot.cpu.cores.count)) / Double(snapshot.cpu.cores.count > 4 ? 2 : 1)))
        coreHeightConstraint?.constant = CGFloat(rows * 24)

        if let gpu = snapshot.gpu, let value = gpu.utilization {
            if let mapped = gpu.inUseSystemMemoryBytes {
                gpuLabel.stringValue = String(format: "GPU  %5.1f%%  ·  mapped %.2f GiB", value * 100, gib(mapped))
            } else {
                gpuLabel.stringValue = String(format: "GPU  %5.1f%%", value * 100)
            }
        } else {
            gpuLabel.stringValue = "GPU  N/A"
        }

        if let memory = snapshot.memory, memory.totalBytes > 0 {
            let percent = memory.totalBytes > 0 ? Double(memory.usedBytes) / Double(memory.totalBytes) * 100 : 0
            memoryLabel.stringValue = String(
                format: "RAM  %.2f / %.2f GiB  (%4.1f%%)",
                gib(memory.usedBytes), gib(memory.totalBytes), percent
            )
            if memory.swapTotalBytes > 0 {
                memoryDetailLabel.stringValue = String(
                    format: "Compressed %.2f GiB  ·  Swap %.2f / %.2f GiB",
                    gib(memory.compressedBytes), gib(memory.swapUsedBytes), gib(memory.swapTotalBytes)
                )
            } else {
                memoryDetailLabel.stringValue = String(
                    format: "Compressed %.2f GiB  ·  Swap 0 GiB",
                    gib(memory.compressedBytes)
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
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
}
