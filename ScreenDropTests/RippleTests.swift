import AppKit
import Metal
import Testing
@testable import ScreenDrop

/// Shader'ı gerçek boru hattıyla ekran dışında çizip belgedeki kesin görsel kuralları doğrular.
@MainActor
struct RippleTests {
    let renderer = RippleRenderer()!
    let size = (w: 400, h: 300)
    /// Dikey ek yerinin solundaki şerit: ek yeri sağ kenarında, geçiş noktası onun ortasında.
    let seam = Seam(a: 0, b: 1, axis: .vertical, position: 400, start: 0, end: 300)
    var strip: Strip { Strip(display: 0, rect: CGRect(x: 0, y: 0, width: 400, height: 300), seamEdge: .right) }

    /// Yazıya benzer ince çizgiler ve kareler: her kayma piksel farkı olarak görünür.
    func pattern() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: size.w * size.h * 4)
        for y in 0..<size.h {
            for x in 0..<size.w {
                let i = (y * size.w + x) * 4
                let line = y % 9 < 2
                let checker = ((x / 12) + (y / 12)) % 2 == 0
                bytes[i] = UInt8(line ? 255 : (checker ? 200 : 40))        // B
                bytes[i + 1] = UInt8((x * 255) / size.w)                   // G
                bytes[i + 2] = UInt8(line ? 255 : (y * 255) / size.h)      // R
                bytes[i + 3] = 255
            }
        }
        return bytes
    }

    func render(time: Float, amplitude: Float = Tuning.amplitude) throws -> (source: [UInt8], output: [UInt8]) {
        let source = pattern()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: RippleRenderer.pixelFormat,
                                                                  width: size.w, height: size.h, mipmapped: false)
        descriptor.usage = [.shaderRead, .renderTarget]
        let input = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let target = try #require(renderer.device.makeTexture(descriptor: descriptor))
        source.withUnsafeBytes {
            input.replace(region: MTLRegionMake2D(0, 0, size.w, size.h), mipmapLevel: 0,
                          withBytes: $0.baseAddress!, bytesPerRow: size.w * 4)
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        let commandBuffer = try #require(renderer.queue.makeCommandBuffer())
        let uniforms = RippleUniforms(strip: strip, seam: seam, crossing: CGPoint(x: 400, y: 150),
                                      time: time, amplitude: amplitude)
        renderer.encode(commandBuffer, pass: pass, source: input, uniforms: uniforms)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var output = [UInt8](repeating: 0, count: size.w * size.h * 4)
        output.withUnsafeMutableBytes {
            target.getBytes($0.baseAddress!, bytesPerRow: size.w * 4, from: MTLRegionMake2D(0, 0, size.w, size.h), mipmapLevel: 0)
        }
        return (source, output)
    }

    func differs(_ a: [UInt8], _ b: [UInt8], at x: Int, _ y: Int) -> Bool {
        let i = (y * size.w + x) * 4
        return (0..<3).contains { abs(Int(a[i + $0]) - Int(b[i + $0])) > 1 }
    }

    @Test func theWaveBendsTheContentNearTheCrossing() throws {
        let (source, output) = try render(time: 0.08)
        let changed = (100..<200).flatMap { y in (250..<400).map { (x: $0, y: y) } }
            .filter { differs(source, output, at: $0.x, $0.y) }.count
        #expect(changed > 2000)
    }

    @Test func nothingMovesAtTheNonSeamEdgesSoNoRectangleShows() throws {
        for time: Float in [0.02, 0.08, 0.2] {
            let (source, output) = try render(time: time, amplitude: Tuning.amplitude * 2)
            for x in 0..<size.w {
                #expect(!differs(source, output, at: x, 0) && !differs(source, output, at: x, size.h - 1))
            }
            for y in 0..<size.h {
                #expect(!differs(source, output, at: 0, y))
            }
        }
    }

    @Test func atTheEndTheOverlayMatchesTheScreenExactly() throws {
        let (source, output) = try render(time: Float(Tuning.duration))
        let changed = (0..<size.h).flatMap { y in (0..<size.w).map { (x: $0, y: y) } }
            .filter { differs(source, output, at: $0.x, $0.y) }.count
        #expect(changed == 0)
    }
}
