import AppKit
import ScreenCaptureKit

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

/// Bir ekranın tamamının anlık görüntüsü; dalga tüm ekrana yayıldığı için bölge değil ekranın hepsi.
final class Capturer {
    private var filters: [CGDirectDisplayID: SCContentFilter] = [:]

    func invalidate() { filters = [:] }

    /// İzin yoksa ya da yakalama başarısızsa nil: efekt görüntüsüz, yalnızca ışıkla oynar.
    func capture(_ screen: NSScreen) async -> Snapshot? {
        guard CGPreflightScreenCaptureAccess(), let id = screen.displayID,
              let filter = await filter(for: id) else { return nil }
        let config = SCStreamConfiguration()
        config.width = Int(screen.frame.width * screen.backingScaleFactor)
        config.height = Int(screen.frame.height * screen.backingScaleFactor)
        // Gerçek imleç zaten en üstte çiziliyor; görüntüde donmuş ikinci bir imleç olmasın.
        config.showsCursor = false
        do {
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return Snapshot(sharp: image, scale: screen.backingScaleFactor)
        } catch {
            NSLog("ScreenDrop capture failed: \(error)")
            return nil
        }
    }

    private func filter(for id: CGDirectDisplayID) async -> SCContentFilter? {
        if let cached = filters[id] { return cached }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.displayID == id }) else { return nil }
            // Kendi overlay panellerimiz görüntüye girmesin.
            let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
            filters[id] = filter
            return filter
        } catch {
            NSLog("ScreenDrop shareable content failed: \(error)")
            return nil
        }
    }
}
