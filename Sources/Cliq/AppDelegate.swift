import Cocoa
import AVFoundation
import ServiceManagement

struct SoundPack {
    let id: String
    let name: String
    let pressResource: String
    let releaseResource: String
    let fullResource: String
}

final class PlayerPool {
    private var players: [AVAudioPlayer] = []
    private var nextIndex = 0

    init?(resource: String, poolSize: Int) {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "wav") else {
            NSLog("Cliq: \(resource).wav not found in bundle Resources")
            return nil
        }
        players = (0..<poolSize).compactMap { _ in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.prepareToPlay()
            return player
        }
        guard !players.isEmpty else { return nil }
    }

    @discardableResult
    func play(volume: Float) -> AVAudioPlayer {
        let player = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        player.volume = volume
        player.currentTime = 0
        player.play()
        return player
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var globalMonitor: Any?
    private let poolSize = 6

    private var pressPool: PlayerPool?
    private var releasePool: PlayerPool?
    private var tapPool: PlayerPool?
    private var activePlayer: AVAudioPlayer?

    private let soundPacks: [SoundPack] = [
        SoundPack(id: "click1", name: "Click 1", pressResource: "click1_press", releaseResource: "click1_release", fullResource: "click1_full"),
        SoundPack(id: "click2", name: "Click 2", pressResource: "click2_press", releaseResource: "click2_release", fullResource: "click2_full"),
        SoundPack(id: "click3", name: "Click 3", pressResource: "click3_press", releaseResource: "click3_release", fullResource: "click3_full"),
    ]

    private let defaults = UserDefaults.standard
    private let enabledKey = "Enabled"
    private let volumeKey = "Volume"
    private let packKey = "SelectedPack"

    private var isEnabled: Bool {
        get { defaults.object(forKey: enabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    private var volume: Float {
        get { defaults.object(forKey: volumeKey) as? Float ?? 1.0 }
        set { defaults.set(newValue, forKey: volumeKey) }
    }

    private var selectedPack: SoundPack {
        let id = defaults.string(forKey: packKey) ?? soundPacks[0].id
        return soundPacks.first(where: { $0.id == id }) ?? soundPacks[0]
    }

    private var loginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadPools(for: selectedPack)
        setupStatusItem()
        setupGlobalMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }

    // MARK: - Status item / menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Cliq")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        menu.addItem(.separator())
        menu.addItem(makeVolumeMenuItem())

        menu.addItem(.separator())

        let packHeader = NSMenuItem(title: "Click Sound", action: nil, keyEquivalent: "")
        packHeader.isEnabled = false
        menu.addItem(packHeader)

        for pack in soundPacks {
            let item = NSMenuItem(title: pack.name, action: #selector(selectPack(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = pack.id
            item.state = pack.id == selectedPack.id ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Cliq", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeVolumeMenuItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 40))

        let label = NSTextField(labelWithString: "Volume")
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 14, y: 20, width: 190, height: 16)
        view.addSubview(label)

        let slider = NSSlider(
            value: Double(volume),
            minValue: 0,
            maxValue: 1,
            target: self,
            action: #selector(volumeChanged(_:))
        )
        slider.isContinuous = true
        slider.frame = NSRect(x: 14, y: 2, width: 192, height: 18)
        view.addSubview(slider)

        item.view = view
        return item
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        isEnabled.toggle()
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        volume = Float(sender.doubleValue)
    }

    @objc private func selectPack(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let pack = soundPacks.first(where: { $0.id == id }) else { return }
        defaults.set(pack.id, forKey: packKey)
        loadPools(for: pack)
        play(tapPool, volume: volume)
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Cliq: failed to toggle login item: \(error)")
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Sound

    private func loadPools(for pack: SoundPack) {
        pressPool = PlayerPool(resource: pack.pressResource, poolSize: poolSize)
        releasePool = PlayerPool(resource: pack.releaseResource, poolSize: poolSize)
        tapPool = PlayerPool(resource: pack.fullResource, poolSize: poolSize)
    }

    @discardableResult
    private func play(_ pool: PlayerPool?, volume: Float) -> AVAudioPlayer? {
        activePlayer?.stop()
        let player = pool?.play(volume: volume)
        activePlayer = player
        return player
    }

    // MARK: - Global mouse monitoring

    private final class PendingPress {
        let date = Date()
        var player: AVAudioPlayer?
        var workItem: DispatchWorkItem?
    }

    // Below this, a click is treated as a tap: the press sound is skipped entirely and only
    // the full, uncut click plays, so its attack transient doesn't land right after the
    // press sound's own transient (which read as a double click).
    private let tapThreshold: TimeInterval = 0.08
    private var pendingPresses: [Int: PendingPress] = [:]

    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp]
        ) { [weak self] event in
            guard let self, self.isEnabled else { return }
            let button = event.buttonNumber
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                guard self.pendingPresses[button] == nil else { return }
                let pending = PendingPress()
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    pending.player = self.play(self.pressPool, volume: self.volume)
                }
                pending.workItem = workItem
                self.pendingPresses[button] = pending
                DispatchQueue.main.asyncAfter(deadline: .now() + self.tapThreshold, execute: workItem)
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                guard let pending = self.pendingPresses.removeValue(forKey: button) else { return }
                if Date().timeIntervalSince(pending.date) < self.tapThreshold {
                    pending.workItem?.cancel()
                    pending.player?.stop()
                    self.play(self.tapPool, volume: self.volume)
                } else {
                    pending.player?.stop()
                    self.play(self.releasePool, volume: self.volume)
                }
            default:
                break
            }
        }
    }
}
