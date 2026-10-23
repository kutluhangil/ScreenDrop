import AppKit
import QuartzCore

/// İmleci ekran yenilemesine bağlı olarak yoklar ve bir ek yerini geçtiği anı bildirir.
/// Yoklama Erişilebilirlik ya da Giriş İzleme izni istemez.
final class Tracker: NSObject {
    var onCross: ((Seam, CGPoint) -> Void)?
    private var frames: [CGRect] = []
    private var primaryHeight: CGFloat = 0
    private var link: CADisplayLink?
    private var previous: (point: CGPoint, display: Int)?
    private var lastTrigger = -Double.infinity

    /// Her ayar değişiminde atanır (UserDefaults bildirimi sık gelir); yalnızca gerçekten değişince sıfırla,
    /// yoksa önceki konum sürekli silinir ve hiçbir geçiş algılanmaz.
    var isPaused = false {
        didSet {
            guard isPaused != oldValue else { return }
            link?.isPaused = isPaused
            previous = nil
        }
    }

    /// Ekran düzeni değişince yeniden kurulur; yoklama ana ekranın yenileme hızında yapılır.
    func configure(frames: [CGRect], primaryHeight: CGFloat, primary: NSScreen?) {
        self.frames = frames
        self.primaryHeight = primaryHeight
        previous = nil
        link?.invalidate()
        link = primary?.displayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
        link?.isPaused = isPaused
    }

    @objc private func tick(_ link: CADisplayLink) {
        let point = Coordinates.flip(NSEvent.mouseLocation, primaryHeight: primaryHeight)
        guard let current = display(containing: point, frames: frames) else {
            previous = nil
            return
        }
        defer { previous = (point, current) }
        guard let prev = previous, prev.display != current,
              let seam = seam(between: prev.display, current, frames: frames),
              let crossing = crossingPoint(from: prev.point, to: point, seam: seam, maxApproach: Tuning.maxApproach)
        else { return }
        // Ek yerinde gidip gelirken efekt üst üste binmesin.
        let now = CACurrentMediaTime()
        guard now - lastTrigger >= Tuning.cooldown else { return }
        lastTrigger = now
        onCross?(seam, crossing)
    }
}
