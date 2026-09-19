import AppKit

final class StatusController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let catView: CatLayerView
    private let popover = NSPopover()
    private let statsController = StatsViewController()
    private let sampler = SystemSampler()
    private let contextMenu = NSMenu()
    private var classicItem: NSMenuItem!
    private var ruslanItem: NSMenuItem!
    private var smoothedSpeed: Double = 0.6

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: 32)
        catView = CatLayerView(frame: NSRect(x: 2, y: 1, width: 28, height: 20))
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
        catView.frame = button.bounds.insetBy(dx: 2, dy: 1)
        button.target = self
        button.action = #selector(statusButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "CPU usage"
    }

    private func setupPopover() {
        popover.contentSize = NSSize(width: 370, height: 360)
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = statsController
    }

    private func setupMenu() {
        classicItem = NSMenuItem(title: "Classic RunCat", action: #selector(selectClassic(_:)), keyEquivalent: "")
        ruslanItem = NSMenuItem(title: "Ruslan outline", action: #selector(selectRuslan(_:)), keyEquivalent: "")
        classicItem.target = self
        ruslanItem.target = self
        classicItem.isEnabled = catView.availableStyles.contains(.classic)
        ruslanItem.isEnabled = catView.availableStyles.contains(.ruslan)
        contextMenu.addItem(classicItem)
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
            self.updateCat(cpu: snapshot.cpu.total)
            self.statusItem.button?.toolTip = String(format: "CPU %.1f%%", snapshot.cpu.total * 100)
            if self.popover.isShown { self.statsController.update(snapshot) }
        }
    }

    private func setupSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func updateCat(cpu: Double) {
        let target = animationSpeed(for: cpu)
        smoothedSpeed += (target - smoothedSpeed) * 0.35
        catView.setCPUSpeed(smoothedSpeed)
    }

    // Closely follows the useful behavior of RuslanDemyanov/RunningCat's speed map,
    // but keeps a small nonzero idle pace and caps the top end at 4x.
    private func animationSpeed(for cpu: Double) -> Double {
        let u = min(1, max(0, cpu))
        switch u {
        case 0..<0.05: return 0.12
        case 0.05..<0.15: return 0.30 + (u - 0.05) * 3.0
        case 0.15..<0.30: return 0.60 + (u - 0.15) * 2.0
        case 0.30..<0.60: return 0.90 + (u - 0.30) * 2.5
        case 0.60..<0.85: return 1.65 + (u - 0.60) * 4.0
        default: return min(4.0, 2.65 + (u - 0.85) * 8.0)
        }
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

    @objc private func selectClassic(_ sender: Any?) {
        catView.setStyle(.classic)
        UserDefaults.standard.set(CatStyle.classic.rawValue, forKey: "CatStyle")
        updateStyleChecks()
    }

    @objc private func selectRuslan(_ sender: Any?) {
        catView.setStyle(.ruslan)
        UserDefaults.standard.set(CatStyle.ruslan.rawValue, forKey: "CatStyle")
        updateStyleChecks()
    }

    private func updateStyleChecks() {
        classicItem?.state = catView.style == .classic ? .on : .off
        ruslanItem?.state = catView.style == .ruslan ? .on : .off
    }

    @objc private func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Cat Menu Bar"
        alert.informativeText = "Native low-overhead CPU cat for macOS.\nCode name: cat_menubar.\n\nClassic RunCat artwork: Takuto Nakamura (Kyome22), Apache-2.0.\nRuslan animation: RuslanDemyanov/RunningCat, Apache-2.0.\n\nSee THIRD_PARTY_NOTICES.md in the app Resources folder for details."
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
