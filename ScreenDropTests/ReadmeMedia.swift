import AppKit
import Metal
import SwiftUI
import Testing
@testable import ScreenDrop

/// README görsellerini üretir: iki ekranlı sahnede efektin kare dizisi (ffmpeg ile GIF'e çevrilir) ve ayarlar
/// penceresinin görüntüsü. Yalnızca SCREENDROP_RENDER_DIR verilince çalışır:
/// `TEST_RUNNER_SCREENDROP_RENDER_DIR=/klasor xcodebuild test ...`
@MainActor
struct ReadmeMedia {
    nonisolated static let dir = ProcessInfo.processInfo.environment["SCREENDROP_RENDER_DIR"].flatMap { $0.isEmpty ? nil : $0 }
    let display = CGSize(width: 1600, height: 1000)

    /// `leading`: pencerenin sol kenarı; ek yerine yakın durması için sağ ekranda küçük, sol ekranda büyük.
    func desktop(_ wallpaper: String, lines: Int, leading: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            if let image = NSImage(contentsOfFile: "/System/Library/Desktop Pictures/\(wallpaper).heic") {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<lines, id: \.self) { i in
                    Text("let crossing = tracker.crossing(from: screen, to: next) // \(i)")
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(i % 5 == 0 ? .pink : .white)
                }
            }
            .padding(36)
            .background(.black.opacity(0.8), in: .rect(cornerRadius: 16))
            .padding(.leading, leading).padding(.top, 180)
        }
        .frame(width: display.width, height: display.height)
        .clipped()
    }

    @Test(.enabled(if: dir != nil)) func dumpEffectFrames() throws {
        let renderer = try #require(RippleRenderer())
        let left = try image(desktop("Sonoma", lines: 22, leading: 760))
        let right = try image(desktop("Mac Purple", lines: 22, leading: 40))
        let frames = [CGRect(origin: .zero, size: display), CGRect(origin: CGPoint(x: display.width, y: 0), size: display)]
        let found = seam(between: 0, 1, frames: frames)
        let shared = try #require(found)
        let (a, b) = strips(for: shared, frames: frames)
        let crossing = CGPoint(x: display.width, y: 520)
        let folder = URL(fileURLWithPath: "\(Self.dir!)/frames")
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // 0,2 sn durgun, ardından 0,7 sn efekt, 0,2 sn durgun; 60 fps.
        for frame in 0..<66 {
            let time = Double(frame) / 60 - 0.2
            let scene = try #require(CGContext(data: nil, width: Int(display.width * 2), height: Int(display.height), bitsPerComponent: 8,
                                               bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                               bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
            let height = display.height
            // CGContext sol-alt orijinli; şeritler sol-üst orijinli global noktalarda.
            func place(_ rect: CGRect) -> CGRect { CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height) }
            scene.draw(left, in: place(frames[0]))
            scene.draw(right, in: place(frames[1]))
            if time >= 0, time < Tuning.duration {
                for (strip, source, origin) in [(a, left, frames[0].origin), (b, right, frames[1].origin)] {
                    let crop = try #require(source.cropping(to: strip.rect.offsetBy(dx: -origin.x, dy: -origin.y)))
                    let output = try render(crop, strip: strip, seam: shared, crossing: crossing, time: Float(time), renderer: renderer)
                    scene.draw(output, in: place(strip.rect))
                }
            }
            let composed = try #require(scene.makeImage())
            let png = try #require(NSBitmapImageRep(cgImage: composed).representation(using: .png, properties: [:]))
            try png.write(to: folder.appendingPathComponent(String(format: "f%03d.png", frame)))
        }
        try writeSettings()
    }

    private func image(_ view: some View) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return try #require(renderer.cgImage)
    }

    /// Gerçek boru hattıyla bir şeridi çizer.
    private func render(_ source: CGImage, strip: Strip, seam: Seam, crossing: CGPoint, time: Float,
                        renderer: RippleRenderer) throws -> CGImage {
        let w = source.width, h = source.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        bytes.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)?
                .draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: RippleRenderer.pixelFormat, width: w, height: h, mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        let input = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let target = try #require(renderer.device.makeTexture(descriptor: descriptor))
        bytes.withUnsafeBytes {
            input.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: w * 4)
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        let commandBuffer = try #require(renderer.queue.makeCommandBuffer())
        renderer.encode(commandBuffer, pass: pass, source: input,
                        uniforms: RippleUniforms(strip: strip, seam: seam, crossing: crossing, time: time, amplitude: Tuning.amplitude))
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        bytes.withUnsafeMutableBytes {
            target.getBytes($0.baseAddress!, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        }
        let context = try #require(bytes.withUnsafeMutableBytes {
            CGContext(data: $0.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space, bitmapInfo: info)
        })
        return try #require(context.makeImage())
    }

    /// AppKit denetimleri ImageRenderer'da çizilmez; gerçek bir NSHostingView'dan alınır.
    private func writeSettings() throws {
        for (name, appearance) in [("settings-dark", NSAppearance.Name.darkAqua), ("settings-light", .aqua)] {
            // Gerçek pencere arka planını kendisi çizer; ekran dışı çekimde onu biz veriyoruz.
            let host = NSHostingView(rootView: SettingsView(test: {}, hasSeam: { true })
                .background(Color(nsColor: .windowBackgroundColor)))
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
}
