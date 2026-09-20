import Foundation
import IOKit

final class GPUReader {
    private var service: io_service_t = 0

    init() {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AGXAccelerator")
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator) == KERN_SUCCESS {
            service = IOIteratorNext(iterator)
            var extra = IOIteratorNext(iterator)
            while extra != 0 {
                IOObjectRelease(extra)
                extra = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
    }

    deinit {
        if service != 0 { IOObjectRelease(service) }
    }

    func sample() -> GPUSnapshot {
        guard service != 0 else { return .unavailable }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS,
              let properties = unmanaged?.takeRetainedValue() as? [String: Any],
              let dictionary = properties["PerformanceStatistics"] as? [String: Any] else {
            return .unavailable
        }

        let utilization: Double?
        if let number = (dictionary["Device Utilization %"] as? NSNumber)
            ?? (dictionary["Renderer Utilization %"] as? NSNumber) {
            // Preserve the driver value. Out-of-range values are useful diagnostics
            // and should remain visible in the graph rather than being hidden.
            utilization = number.doubleValue / 100.0
        } else {
            utilization = nil
        }

        // Apple Silicon shares DRAM with the GPU. This is mapped system memory, not dedicated VRAM.
        let memoryNumber = (dictionary["Alloc system memory"] as? NSNumber)
            ?? (dictionary["In use system memory"] as? NSNumber)
            ?? (dictionary["In use system memory (driver)"] as? NSNumber)
        let memory = memoryNumber.map { UInt64(max(0, $0.int64Value)) }

        return GPUSnapshot(utilization: utilization, inUseSystemMemoryBytes: memory)
    }
}
