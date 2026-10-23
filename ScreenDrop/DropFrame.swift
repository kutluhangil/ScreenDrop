import CoreImage
import SwiftUI

/// Bir ekrandaki efektin tek karesi. Zaman dışarıdan verilir; uygulamada TimelineView, testte sabit değerler.
struct DropFrame: View {
    /// Efektin çizildiği bölge, ekran-yerel sol-üst orijinli noktalar.
    let region: CGRect
    /// Geçiş noktası, ekran-yerel.
    let origin: CGPoint
    /// Kenardan bu ekranın içine doğru birim vektör.
    let normal: CGVector
    let snapshot: Snapshot?
    let charge: Double
    /// Geçişten beri geçen saniye; nil ise patlama yok.
    let burst: Double?
    var style = EffectStyle.airDrop
    var brightness = 1.0

    var body: some View {
        let local = CGPoint(x: origin.x - region.minX, y: origin.y - region.minY)
        ZStack {
            if let snapshot {
                Image(decorative: snapshot.sharp, scale: snapshot.scale).resizable()
            } else {
                // Color.clear çizilmez, shader hiç çalışmaz: görünmez ama boş olmayan katman.
                Color.black.opacity(0.004)
            }
        }
        .frame(width: region.width, height: region.height)
        .layerEffect(
            ShaderLibrary.nameDrop(
                .image(Image(decorative: snapshot?.blurred ?? Snapshot.clearPixel, scale: snapshot?.scale ?? 1)),
                .float2(region.size), .float2(local), .float2(Float(normal.dx), Float(normal.dy)),
                .float(Float(charge)), .float(Float(burst ?? -1)), .float(snapshot == nil ? 0 : 1),
                .float(style == .airDrop ? 1 : 0), .float(Float(brightness))
            ),
            maxSampleOffset: CGSize(width: 80, height: 80)
        )
        .offset(x: region.minX, y: region.minY)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Bir bölgenin net hali ve shader'ın karıştırdığı bulanık hali.
struct Snapshot {
    let sharp: CGImage
    let blurred: CGImage
    let scale: CGFloat
    let capturedAt: Date

    static let clearPixel: CGImage = {
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }()

    private static let ciContext = CIContext()

    init?(sharp: CGImage, scale: CGFloat, capturedAt: Date = Date()) {
        let input = CIImage(cgImage: sharp)
        // Apple'ın disk içi bulanıklığı çok güçlü; 28 pt Retina'da 56 px.
        let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: 28 * scale).cropped(to: input.extent)
        guard let image = Self.ciContext.createCGImage(blurred, from: input.extent) else { return nil }
        self.sharp = sharp
        self.blurred = image
        self.scale = scale
        self.capturedAt = capturedAt
    }
}
