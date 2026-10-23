import Metal
import simd

/// Ripple.metal'deki `RippleUniforms` ile birebir aynı düzen.
struct RippleUniforms {
    var stripOrigin: SIMD2<Float>
    var stripSize: SIMD2<Float>
    var crossing: SIMD2<Float>
    var time: Float
    var amplitude: Float
    var speed: Float = Tuning.speed
    var width: Float = Tuning.width
    var wavelength: Float = Tuning.wavelength
    var tau: Float = Tuning.tau
    var seamPosition: Float
    var duration = Float(Tuning.duration)
    var seamVertical: Int32
    var seamEdge: Int32
    var chromatic: Int32 = 0
    var debug: Int32 = 0

    init(strip: Strip, seam: Seam, crossing: CGPoint, time: Float, amplitude: Float) {
        stripOrigin = SIMD2(Float(strip.rect.minX), Float(strip.rect.minY))
        stripSize = SIMD2(Float(strip.rect.width), Float(strip.rect.height))
        self.crossing = SIMD2(Float(crossing.x), Float(crossing.y))
        self.time = time
        self.amplitude = amplitude
        seamPosition = Float(seam.position)
        seamVertical = seam.axis == .vertical ? 1 : 0
        seamEdge = strip.seamEdge.rawValue
    }
}

/// Metal aygıtı ve ripple boru hattı; tüm şerit pencereleri ve ekran dışı çizim (testler) paylaşır.
final class RippleRenderer {
    let device: MTLDevice
    let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    static let pixelFormat = MTLPixelFormat.bgra8Unorm

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "rippleVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "rippleFragment")
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        guard let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor) else { return nil }
        self.device = device
        self.queue = queue
        self.pipeline = pipeline
    }

    func encode(_ commandBuffer: MTLCommandBuffer, pass: MTLRenderPassDescriptor, source: MTLTexture,
                uniforms: RippleUniforms) {
        var uniforms = uniforms
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(source, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RippleUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }
}
