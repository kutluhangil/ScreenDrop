import AppKit
import SwiftUI
import Testing
@testable import ScreenDrop

/// README görsellerini üretir: iki monitörde her iki stilin kare dizisi (ffmpeg ile GIF'e çevrilir)
/// ve ayarlar penceresinin görüntüsü. Yalnızca SCREENDROP_RENDER_DIR verilince çalışır:
/// `TEST_RUNNER_SCREENDROP_RENDER_DIR=/klasor xcodebuild test ...`
@MainActor
struct RenderFrames {
    nonisolated static let dir = ProcessInfo.processInfo.environment["SCREENDROP_RENDER_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    let size = CGSize(width: 1600, height: 1000)

    func desktop(_ wallpaper: String) -> some View {
        ZStack(alignment: .topLeading) {
            if let image = NSImage(contentsOfFile: "/System/Library/Desktop Pictures/\(wallpaper).heic") {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            }
            VStack(alignment: .leading, spacing: 9) {
                ForEach(0..<20) { i in
                    Text("let crossing = watcher.crossing(from: screen, to: next) // \(i)")
                        .font(.system(size: 19, design: .monospaced))
                        .foregroundStyle(i % 5 == 0 ? .pink : .white)
                }
            }
            .padding(34)
            .background(.black.opacity(0.78), in: .rect(cornerRadius: 16))
            .padding(.leading, 260).padding(.top, 230)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @Test(.enabled(if: dir != nil)) func dumpReadmeMedia() throws {
        let left = try snapshot(of: desktop("Sonoma"))
        let right = try snapshot(of: desktop("Mac Purple"))
        let region = CGRect(origin: .zero, size: size)
        for style in EffectStyle.allCases {
            let folder = URL(fileURLWithPath: "\(Self.dir!)/\(style.rawValue)")
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            // 0,6 sn yaklaşma (charge 0 → 1), ardından patlama; 30 fps.
            let approach = 0.6
            let frames = Int((approach + style.duration + 0.25) * 30)
            for frame in 0..<frames {
                let time = Double(frame) / 30
                let charge = time < approach ? pow(time / approach, 2) : max(0, 1 - (time - approach) / 0.35)
                let burst = time < approach ? nil : time - approach
                let view = HStack(spacing: 24) {
                    DropFrame(region: region, origin: CGPoint(x: size.width, y: size.height / 2),
                              normal: CGVector(dx: -1, dy: 0), snapshot: left, charge: charge, burst: burst, style: style)
                        .frame(width: size.width, height: size.height)
                        .clipShape(.rect(cornerRadius: 18))
                    DropFrame(region: region, origin: CGPoint(x: 0, y: size.height / 2),
                              normal: CGVector(dx: 1, dy: 0), snapshot: right, charge: charge, burst: burst, style: style)
                        .frame(width: size.width, height: size.height)
                        .clipShape(.rect(cornerRadius: 18))
                }
                .padding(24)
                .background(Color(white: 0.07))
                let renderer = ImageRenderer(content: view)
                renderer.scale = 0.5
                let image = try #require(renderer.cgImage)
                try write(image, to: folder.appendingPathComponent(String(format: "f%03d.png", frame)))
            }
        }
        try writeSettings()
    }

    private func snapshot(of view: some View) throws -> Snapshot {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        return try #require(Snapshot(sharp: image, scale: 1))
    }

    /// AppKit denetimleri (anahtar, kaydırıcı) ImageRenderer'da çizilmez; gerçek bir NSHostingView'dan alınır.
    private func writeSettings() throws {
        for (name, appearance) in [("settings-dark", NSAppearance.Name.darkAqua), ("settings-light", .aqua)] {
            let host = NSHostingView(rootView: SettingsView(preview: {}))
            host.appearance = NSAppearance(named: appearance)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: "\(Self.dir!)/\(name).png"))
        }
    }

    private func write(_ image: CGImage, to url: URL) throws {
        let png = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
