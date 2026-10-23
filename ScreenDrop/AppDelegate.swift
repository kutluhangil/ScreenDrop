import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let effect = EffectController()
    private var statusMenu: StatusMenu?
    private var settingsWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        effect.start()
        statusMenu = StatusMenu(effect: effect) { [weak self] in self?.showSettings() }
        // İlk açılışta izin yoksa ne yapılacağını anlatan ayarlar penceresini göster.
        if !CGPreflightScreenCaptureAccess() { showSettings() }
    }

    private func showSettings() {
        if settingsWindow == nil {
            let effect = self.effect
            let controller = NSHostingController(rootView: SettingsView(test: { effect.test() }, hasSeam: { effect.hasSeam }))
            let window = NSWindow(contentViewController: controller)
            window.title = "ScreenDrop"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Menü çubuğu öğesi: Etkin, Yoğunluk, Efekti test et, Ayarlar, Çık.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let effect: EffectController
    private let openSettings: () -> Void
    private let enabledItem = NSMenuItem(title: "Etkin", action: #selector(toggleEnabled), keyEquivalent: "")
    private let testItem = NSMenuItem(title: "Efekti test et", action: #selector(test), keyEquivalent: "t")
    private let slider = NSSlider(value: 1, minValue: Preferences.intensityRange.lowerBound,
                                  maxValue: Preferences.intensityRange.upperBound, target: nil, action: nil)

    init(effect: EffectController, openSettings: @escaping () -> Void) {
        self.effect = effect
        self.openSettings = openSettings
        super.init()
        item.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle.angled", accessibilityDescription: "ScreenDrop")
        let menu = NSMenu()
        menu.delegate = self
        // "Efekti test et" ek yeri ya da izin yokken pasif kalsın; otomatik etkinleştirme bunu ezerdi.
        menu.autoenablesItems = false
        enabledItem.target = self
        testItem.target = self
        slider.target = self
        slider.action = #selector(intensityChanged)
        slider.setAccessibilityLabel("Yoğunluk")
        menu.addItem(enabledItem)
        menu.addItem(sliderItem())
        menu.addItem(testItem)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Ayarlar…", action: #selector(settings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
    }

    private func sliderItem() -> NSMenuItem {
        let label = NSTextField(labelWithString: "Yoğunluk")
        label.font = .menuFont(ofSize: 0)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [label, slider])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 20, bottom: 6, right: 20)
        stack.frame = NSRect(x: 0, y: 0, width: 240, height: 54)
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let item = NSMenuItem()
        item.view = stack
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let preferences = Preferences.load()
        enabledItem.state = preferences.enabled ? .on : .off
        slider.doubleValue = preferences.intensity
        testItem.isEnabled = effect.hasSeam && CGPreflightScreenCaptureAccess()
    }

    @objc private func toggleEnabled() {
        UserDefaults.standard.set(!Preferences.load().enabled, forKey: Preferences.Key.enabled)
    }

    @objc private func intensityChanged() {
        UserDefaults.standard.set(slider.doubleValue, forKey: Preferences.Key.intensity)
    }

    @objc private func test() { effect.test() }

    @objc private func settings() { openSettings() }
}
