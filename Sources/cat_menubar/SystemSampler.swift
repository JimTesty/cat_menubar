import Foundation

final class SystemSampler {
    var onSnapshot: ((SystemSnapshot) -> Void)?

    private let queue = DispatchQueue(label: "local.cat-menubar.sampler", qos: .utility)
    private let cpu = CPUSampler()
    private let memory = MemorySampler()
    private let gpu = GPUReader()
    private var timer: DispatchSourceTimer?
    private var detailed = false
    private var running = false

    func start() {
        queue.async { [weak self] in
            guard let self = self, !self.running else { return }
            self.running = true
            self.cpu.reset()
            self.memory.start(on: self.queue)
            self.installTimer()
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.running = false
            self.timer?.setEventHandler {}
            self.timer?.cancel()
            self.timer = nil
            self.memory.stop()
            self.cpu.reset()
        }
    }

    func setDetailed(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard self.detailed != enabled else { return }
            self.detailed = enabled
            if self.running { self.installTimer() }
        }
    }

    private func installTimer() {
        timer?.setEventHandler {}
        timer?.cancel()

        let source = DispatchSource.makeTimerSource(queue: queue)
        let interval = detailed ? AppConfig.Sampling.detailedInterval : AppConfig.Sampling.normalInterval
        source.schedule(deadline: .now(), repeating: interval, leeway: AppConfig.Sampling.timerLeeway)
        source.setEventHandler { [weak self] in self?.tick() }
        timer = source
        source.resume()
    }

    private func tick() {
        guard running else { return }

        let cpuSnapshot = cpu.sample()
        let snapshot: SystemSnapshot
        if detailed {
            snapshot = SystemSnapshot(
                cpu: cpuSnapshot,
                memory: memory.sample(),
                gpu: gpu.sample()
            )
        } else {
            snapshot = SystemSnapshot(cpu: cpuSnapshot, memory: nil, gpu: nil)
        }

        DispatchQueue.main.async { [weak self] in
            self?.onSnapshot?(snapshot)
        }
    }
}
