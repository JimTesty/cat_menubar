import AppKit

final class StatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let catView: CatLayerView
    private let popover = NSPopover()
    private let statsController = StatsViewController()
    private let sampler = SystemSampler()
    private let contextMenu = NSMenu()
    private var kyomeItem: NSMenuItem!
    private var ruslanItem: NSMenuItem!
    private var smoothedCPU = ExponentialSmoother(
        timeConstant: AppConfig.Sampling.cpuDisplaySmoothingTimeConstant
    )
    private var smoothedGPU = ExponentialSmoother(
        timeConstant: AppConfig.Sampling.cpuDisplaySmoothingTimeConstant
    )
    private var smoothedSpeed = ExponentialSmoother(
        timeConstant: AppConfig.Sampling.animationSpeedSmoothingTimeConstant,
        initialValue: AppConfig.Animation.initialSpeed
    )

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: AppConfig.StatusItem.length)
        catView = CatLayerView(frame: AppConfig.StatusItem.initialCatFrame)
        super.init()

        setupStatusItem()
        setupPopover()
        if let saved = UserDefaults.standard.string(forKey: "CatStyle"),
           let style = CatStyle(rawValue: saved),
           catView.availableStyles.contains(style) {
            catView.setStyle(style)
        }
        setupMenu()
        setupSampler()
        setupSleepWake()
        sampler.start()
    }

    deinit {
        sampler.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.addSubview(catView)
        catView.autoresizingMask = [.width, .height]
        catView.frame = button.bounds.insetBy(
            dx: AppConfig.StatusItem.catFrameInset.width,
            dy: AppConfig.StatusItem.catFrameInset.height
        )
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "CPU usage"
    }

    private func setupPopover() {
        popover.contentSize = AppConfig.Popover.size
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = statsController
    }

    private func setupMenu() {
        kyomeItem = NSMenuItem(title: "Kyome22 RunCat", action: #selector(selectKyome(_:)), keyEquivalent: "")
        ruslanItem = NSMenuItem(title: "Ruslan RunningCat", action: #selector(selectRuslan(_:)), keyEquivalent: "")
        kyomeItem.target = self
        ruslanItem.target = self
        kyomeItem.isEnabled = catView.availableStyles.contains(.kyome)
        ruslanItem.isEnabled = catView.availableStyles.contains(.ruslan)
        contextMenu.addItem(kyomeItem)
        contextMenu.addItem(ruslanItem)
        contextMenu.addItem(.separator())

        let about = NSMenuItem(title: "About Cat Menu Bar", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        contextMenu.addItem(about)

        let quit = NSMenuItem(title: "Quit Cat Menu Bar", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        contextMenu.addItem(quit)
        updateStyleChecks()
    }

    private func setupSampler() {
        sampler.onSnapshot = { [weak self] snapshot in
            guard let self = self else { return }
            let timestamp = ProcessInfo.processInfo.systemUptime
            let displayCPU: Double
            if snapshot.cpu.total.isFinite {
                displayCPU = self.smoothedCPU.update(snapshot.cpu.total, at: timestamp)
            } else {
                self.smoothedCPU.reset()
                displayCPU = snapshot.cpu.total
            }
            var displayedSnapshot = snapshot
            displayedSnapshot.cpu.total = displayCPU
            if var gpu = displayedSnapshot.gpu, let utilization = gpu.utilization {
                if utilization.isFinite {
                    gpu.utilization = self.smoothedGPU.update(utilization, at: timestamp)
                } else {
                    self.smoothedGPU.reset()
                }
                displayedSnapshot.gpu = gpu
            } else {
                self.smoothedGPU.reset()
            }
            if displayCPU.isFinite {
                self.updateCat(cpu: displayCPU, at: timestamp)
                self.statusItem.button?.toolTip = String(format: "CPU %.1f%%", displayCPU * 100)
            } else {
                self.statusItem.button?.toolTip = "CPU invalid sample"
            }
            self.statsController.recordHistory(displayedSnapshot, at: timestamp)
            if self.popover.isShown { self.statsController.update(displayedSnapshot) }
        }
    }

    private func setupSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func updateCat(cpu: Double, at timestamp: TimeInterval) {
        let target = animationSpeed(for: cpu)
        let speed = smoothedSpeed.update(target, at: timestamp)
        catView.setCPUSpeed(speed)
    }

    // Closely follows the useful behavior of RuslanDemyanov/RunningCat's speed map,
    // but keeps a small nonzero idle pace and caps the top end at 4x.
    private func animationSpeed(for cpu: Double) -> Double {
        let u = min(1, max(0, cpu))
        if u < AppConfig.Animation.idleLoadUpperBound {
            return AppConfig.Animation.idleSpeed
        }
        if u < AppConfig.Animation.lowLoadUpperBound {
            return AppConfig.Animation.lowLoadBaseSpeed
                + (u - AppConfig.Animation.idleLoadUpperBound) * AppConfig.Animation.lowLoadSlope
        }
        if u < AppConfig.Animation.mediumLoadUpperBound {
            return AppConfig.Animation.mediumLoadBaseSpeed
                + (u - AppConfig.Animation.lowLoadUpperBound) * AppConfig.Animation.mediumLoadSlope
        }
        if u < AppConfig.Animation.highLoadUpperBound {
            return AppConfig.Animation.highLoadBaseSpeed
                + (u - AppConfig.Animation.mediumLoadUpperBound) * AppConfig.Animation.highLoadSlope
        }
        if u < AppConfig.Animation.veryHighLoadUpperBound {
            return AppConfig.Animation.veryHighLoadBaseSpeed
                + (u - AppConfig.Animation.highLoadUpperBound) * AppConfig.Animation.veryHighLoadSlope
        }
        return min(
            AppConfig.Animation.maximumSpeed,
            AppConfig.Animation.maximumLoadBaseSpeed
                + (u - AppConfig.Animation.veryHighLoadUpperBound) * AppConfig.Animation.maximumLoadSlope
        )
    }

    @objc private func statusButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            if popover.isShown { popover.performClose(nil) }
            contextMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY), in: sender)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            sampler.setDetailed(true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        sampler.setDetailed(false)
    }

    @objc private func selectKyome(_ sender: Any?) {
        catView.setStyle(.kyome)
        UserDefaults.standard.set(CatStyle.kyome.rawValue, forKey: "CatStyle")
        updateStyleChecks()
    }

    @objc private func selectRuslan(_ sender: Any?) {
        catView.setStyle(.ruslan)
        UserDefaults.standard.set(CatStyle.ruslan.rawValue, forKey: "CatStyle")
        updateStyleChecks()
    }

    private func updateStyleChecks() {
        kyomeItem?.state = catView.style == .kyome ? .on : .off
        ruslanItem?.state = catView.style == .ruslan ? .on : .off
    }

    @objc private func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Cat Menu Bar"
        alert.informativeText = "Native low-overhead CPU cat for macOS.\n\nKyome22 RunCat artwork: Takuto Nakamura, Apache-2.0.\nRuslan RunningCat animation: RuslanDemyanov, Apache-2.0.\n\nSee THIRD_PARTY_NOTICES.md in the app Resources folder for details."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    @objc private func willSleep(_ note: Notification) {
        sampler.stop()
        catView.pause()
    }

    @objc private func didWake(_ note: Notification) {
        catView.resume()
        sampler.start()
    }
}
