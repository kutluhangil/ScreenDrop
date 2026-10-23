import AppKit
import SwiftUI

@main
struct ScreenDropApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage(Preferences.Key.enabled) private var enabled = Preferences().enabled

    var body: some Scene {
        MenuBarExtra("ScreenDrop", systemImage: "rectangle.on.rectangle.angled") {
            MenuContent(enabled: $enabled, preview: delegate.coordinator.preview)
        }
        Window("ScreenDrop", id: "settings") {
            SettingsView(preview: delegate.coordinator.preview)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

private struct MenuContent: View {
    @Binding var enabled: Bool
    let preview: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Etkin", isOn: $enabled)
        Button("Önizle", action: preview)
            .disabled(!enabled)
        Divider()
        Button("Ayarlar…") {
            openWindow(id: "settings")
            // Menü çubuğu uygulaması: pencere öne gelsin.
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Çık") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = Coordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }
}
