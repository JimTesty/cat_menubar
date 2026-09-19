import Darwin
import Dispatch
import Foundation

final class MemorySampler {
    private var pressureLevel: MemoryPressureLevel = .normal
    private var pressureSource: DispatchSourceMemoryPressure?

    func start(on queue: DispatchQueue) {
        guard pressureSource == nil else { return }

        pressureLevel = .normal
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )
        source.setEventHandler { [weak self, source] in
            guard let self = self else { return }
            if source.data.contains(.critical) {
                self.pressureLevel = .critical
            } else if source.data.contains(.warning) {
                self.pressureLevel = .warning
            } else if source.data.contains(.normal) {
                self.pressureLevel = .normal
            }
        }
        pressureSource = source
        source.resume()
    }

    func stop() {
        pressureSource?.setEventHandler {}
        pressureSource?.cancel()
        pressureSource = nil
        pressureLevel = .normal
    }

    func sample() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )

        let kr: kern_return_t = withUnsafeMutablePointer(to: &stats) { statsPointer in
            statsPointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let total = ProcessInfo.processInfo.physicalMemory
        guard kr == KERN_SUCCESS else {
            let swap = readSwap()
            return MemorySnapshot(
                totalBytes: total,
                usedBytes: 0,
                compressedBytes: 0,
                swapUsedBytes: swap.used,
                swapTotalBytes: swap.total,
                pressure: pressureLevel
            )
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)

        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let speculative = UInt64(stats.speculative_count) * page
        let wired = UInt64(stats.wire_count) * page
        let compressed = UInt64(stats.compressor_page_count) * page
        let purgeable = UInt64(stats.purgeable_count) * page
        let external = UInt64(stats.external_page_count) * page

        // Approximation used by longstanding macOS monitors: count occupied VM pages,
        // then subtract file-backed / purgeable cache that can be reclaimed cheaply.
        let occupied = active &+ inactive &+ speculative &+ wired &+ compressed
        let reclaimable = min(occupied, purgeable &+ external)
        let used = min(total, occupied &- reclaimable)

        let swap = readSwap()
        return MemorySnapshot(
            totalBytes: total,
            usedBytes: used,
            compressedBytes: compressed,
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            pressure: pressureLevel
        )
    }

    private func readSwap() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else { return (0, 0) }
        return (UInt64(usage.xsu_used), UInt64(usage.xsu_total))
    }
}
