import Darwin
import Foundation

struct ExponentialSmoother {
    private let timeConstant: TimeInterval
    private var value: Double?
    private var lastTimestamp: TimeInterval?

    init(timeConstant: TimeInterval, initialValue: Double? = nil) {
        precondition(timeConstant > 0)
        self.timeConstant = timeConstant
        self.value = initialValue
    }

    mutating func update(_ target: Double, at timestamp: TimeInterval) -> Double {
        guard target.isFinite else { return value ?? 0 }

        guard let current = value else {
            value = target
            lastTimestamp = timestamp
            return target
        }

        let elapsed = max(0, timestamp - (lastTimestamp ?? timestamp))
        let alpha = elapsed > 0 ? 1 - exp(-elapsed / timeConstant) : 0
        let next = current + (target - current) * alpha
        value = next
        lastTimestamp = timestamp
        return next
    }

    mutating func reset(to value: Double? = nil) {
        self.value = value
        lastTimestamp = nil
    }
}
