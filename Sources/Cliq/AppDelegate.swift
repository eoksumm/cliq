import Cocoa
import AVFoundation
import ServiceManagement

struct SoundPack {
    let id: String
    let name: String
    let pressResource: String
    let releaseResource: String
}

// A small round-robin pool so rapid repeated clicks don't cut each other's playback off.
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

    func play(volume: Float) {
        let player = players[nextIndex]
        nextIndex = (nextIndex + 1) % players.count
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private var globalMonitor: Any?
    private let poolSize = 6

    private var pressPool: PlayerPool?
    private var releasePool: PlayerPool?

    private let soundPacks: [SoundPack] = [
        SoundPack(id: "click1", name: "Click 1", pressResource: "click1_press", releaseResource: "click1_release"),
        SoundPack(id: "click2", name: "Click 2", pressResource: "click2_press", releaseResource: "click2_release"),
        SoundPack(id: "click3", name: "Click 3", pressResource: "click3_press", releaseResource: "click3_release"),
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
        pressPool?.play(volume: volume) // preview
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
    }

    // MARK: - Global mouse monitoring

    // Trackpad taps (Tap to Click) fire mouseDown/mouseUp almost instantly, so the press
    // and release sounds would start on top of each other and mush together. A real held
    // click has a natural gap between down and up, so below this threshold we treat it as
    // a tap and skip the release sound.
    private let tapThreshold: TimeInterval = 0.08
    private var pressTimestamps: [Int: Date] = [:]

    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseUp, .rightMouseUp, .otherMouseUp]
        ) { [weak self] event in
            guard let self, self.isEnabled else { return }
            switch event.type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                self.pressTimestamps[event.buttonNumber] = Date()
                self.pressPool?.play(volume: self.volume)
            case .leftMouseUp, .rightMouseUp, .otherMouseUp:
                let pressedAt = self.pressTimestamps.removeValue(forKey: event.buttonNumber)
                let wasTap = pressedAt.map { Date().timeIntervalSince($0) < self.tapThreshold } ?? false
                if !wasTap {
                    self.releasePool?.play(volume: self.volume)
                }
            default:
                break
            }
        }
    }
}
