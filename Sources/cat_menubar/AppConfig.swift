import Foundation

enum AppConfig {
    enum Sampling {
        static let normalInterval: DispatchTimeInterval = .seconds(1)
        static let detailedInterval: DispatchTimeInterval = .milliseconds(500)
        static let diskSampleTickInterval = 2
        static let backgroundGPUInterval: TimeInterval = 1
        static let timerLeeway: DispatchTimeInterval = .milliseconds(80)
        static let cpuDisplaySmoothingTimeConstant: TimeInterval = 1.5
        static let animationSpeedSmoothingTimeConstant: TimeInterval = 0.8
    }

    enum Animation {
        static let initialSpeed = 0.6
        static let minimumSpeed = 0.08
        static let maximumSpeed = 4.0
        static let kyomeFrameDuration: TimeInterval = 0.10
        static let ruslanFramesPerSecond = 25.0

        static let idleLoadUpperBound = 0.05
        static let lowLoadUpperBound = 0.15
        static let mediumLoadUpperBound = 0.30
        static let highLoadUpperBound = 0.60
        static let veryHighLoadUpperBound = 0.85

        static let idleSpeed = 0.12
        static let lowLoadBaseSpeed = 0.30
        static let lowLoadSlope = 3.0
        static let mediumLoadBaseSpeed = 0.60
        static let mediumLoadSlope = 2.0
        static let highLoadBaseSpeed = 0.90
        static let highLoadSlope = 2.5
        static let veryHighLoadBaseSpeed = 1.65
        static let veryHighLoadSlope = 4.0
        static let maximumLoadBaseSpeed = 2.65
        static let maximumLoadSlope = 8.0
    }

    enum Ruslan {
        static let rasterSize: CGFloat = 256
        static let fillShapesSolid = true
    }

    enum StatusItem {
        static let length: CGFloat = 32
        static let initialCatFrame = CGRect(x: 2, y: 1, width: 28, height: 20)
        static let catFrameInset = CGSize(width: 2, height: 1)
    }

    enum Popover {
        static let size = CGSize(width: 370, height: 382)
        static let horizontalInset: CGFloat = 16
        static let topInset: CGFloat = 14
        static let bottomInset: CGFloat = 12
        static let stackSpacing: CGFloat = 7
        static let coreBarsHeight: CGFloat = 104
        static let coreRowHeight: CGFloat = 24
        static let cpuLabelAreaHeight: CGFloat = 30
        static let cpuToCoresSpacing: CGFloat = 8
    }

    enum CoreBars {
        static let minimumRowHeight: CGFloat = 20
        static let maximumRowHeight: CGFloat = 26
        static let labelWidth: CGFloat = 56
        static let percentWidth: CGFloat = 44
        static let padding: CGFloat = 6
        static let barHeight: CGFloat = 8
        static let barCornerRadius: CGFloat = 3
        static let labelTopOffset: CGFloat = 3
        static let barTopOffset: CGFloat = 6
        static let textBottomInset: CGFloat = 4
        static let minimumBarWidth: CGFloat = 12
        static let minimumVisibleBarWidth: CGFloat = 0.5
    }

    enum History {
        static let duration: TimeInterval = 60
        static let maximumGap: TimeInterval = 3
        static let graphHeight: CGFloat = 52
        static let lineWidth: CGFloat = 1.5
        static let cpuLineWidth: CGFloat = 1.8
    }

    enum Typography {
        static let cpuSize: CGFloat = 24
        static let metricSize: CGFloat = 14
        static let sectionSize: CGFloat = 10
        static let noteSize: CGFloat = 10
        static let coreSize: CGFloat = 10.5
    }
}
