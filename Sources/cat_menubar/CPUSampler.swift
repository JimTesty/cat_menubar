import Darwin
import Foundation

final class CPUSampler {
    private struct Ticks {
        var user: UInt32
        var system: UInt32
        var idle: UInt32
        var nice: UInt32
    }

    private var previous: [Ticks] = []

    func reset() {
        previous.removeAll(keepingCapacity: true)
    }

    func sample() -> CPUSnapshot {
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        var cpuCount: natural_t = 0

        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &info,
            &infoCount
        )

        guard kr == KERN_SUCCESS, let info = info else {
            return .empty
        }

        defer {
            let byteCount = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), byteCount)
        }

        let count = Int(cpuCount)
        var current = [Ticks]()
        current.reserveCapacity(count)

        for cpu in 0..<count {
            let base = cpu * Int(CPU_STATE_MAX)
            current.append(Ticks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)])
            ))
        }

        guard previous.count == current.count else {
            previous = current
            return CPUSnapshot(total: 0, cores: Array(repeating: 0, count: count))
        }

        var coreUsage = [Double]()
        coreUsage.reserveCapacity(count)
        var allBusy: UInt64 = 0
        var allTicks: UInt64 = 0

        for i in 0..<count {
            let now = current[i]
            let old = previous[i]

            // CPU tick counters are 32-bit on Darwin. Wrapping subtraction handles rollover.
            let user = UInt64(now.user &- old.user)
            let system = UInt64(now.system &- old.system)
            let idle = UInt64(now.idle &- old.idle)
            let nice = UInt64(now.nice &- old.nice)
            let busy = user + system + nice
            let total = busy + idle

            allBusy += busy
            allTicks += total
            coreUsage.append(total > 0 ? min(1, max(0, Double(busy) / Double(total))) : 0)
        }

        previous = current
        let aggregate = allTicks > 0 ? min(1, max(0, Double(allBusy) / Double(allTicks))) : 0
        return CPUSnapshot(total: aggregate, cores: coreUsage)
    }
}
