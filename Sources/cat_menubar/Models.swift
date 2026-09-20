import Foundation

struct CPUSnapshot {
    var total: Double
    var cores: [Double]

    static let empty = CPUSnapshot(total: 0, cores: [])
}

enum MemoryPressureLevel: String {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

struct MemorySnapshot {
    var totalBytes: UInt64
    var usedBytes: UInt64
    var compressedBytes: UInt64
    var swapUsedBytes: UInt64
    var swapTotalBytes: UInt64
    var diskFreeBytes: UInt64?
    var pressure: MemoryPressureLevel

    static let empty = MemorySnapshot(
        totalBytes: 0,
        usedBytes: 0,
        compressedBytes: 0,
        swapUsedBytes: 0,
        swapTotalBytes: 0,
        diskFreeBytes: nil,
        pressure: .normal
    )
}

struct GPUSnapshot {
    var utilization: Double?
    var inUseSystemMemoryBytes: UInt64?

    static let unavailable = GPUSnapshot(utilization: nil, inUseSystemMemoryBytes: nil)
}

struct SystemSnapshot {
    var cpu: CPUSnapshot
    var memory: MemorySnapshot?
    var gpu: GPUSnapshot?
}

enum CatStyle: String, Hashable {
    case kyome
    case ruslan
}
