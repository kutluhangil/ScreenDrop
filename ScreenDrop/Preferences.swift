import Foundation

/// Efektin ayarlanabilir sabitleri (seam-ripple-prompt.md, Faz 4). Yoğunluk ayarı genliği ölçekler.
enum Tuning {
    static let amplitude: Float = 14        // pt, tam yoğunlukta
    static let speed: Float = 1400          // pt/sn, dalga cephesinin hızı
    static let width: Float = 70            // pt, cephe zarfının genişliği
    static let wavelength: Float = 90       // pt
    static let tau: Float = 0.25            // sn, sönüm süresi
    /// Belgedeki "yaklaşık 700 ms" süresi. exp(-t/τ) bu anda ~0,06'dır; shader son 30% içinde tam sıfıra indirir.
    static let duration: Double = 0.7
    static let stripDepth: CGFloat = 360    // pt, ek yerinin her iki yanında
    static let stripMargin: CGFloat = 120   // pt, ortak parçanın uçlarından taşma
    static let maxApproach: CGFloat = 40    // pt, bundan uzaktan gelen geçiş sıçrama sayılır
    static let cooldown: Double = 0.45      // sn
    /// Hareketi Azalt açıkken genlik çarpanı.
    static let reducedMotion: Float = 0.3
}

/// Ayarlar; ayarlar penceresi ve menü aynı anahtarları okur ve yazar.
struct Preferences {
    enum Key {
        static let enabled = "enabled"
        static let intensity = "intensity"
        static let skipFullScreen = "skipFullScreen"
        static let chromatic = "chromatic"
        /// Gizli: `defaults write com.kutluhangil.ScreenDrop debug -bool true`
        static let debug = "debug"
    }

    static let intensityRange = 0.2...2.0

    var enabled = true
    var intensity = 1.0
    var skipFullScreen = true
    var chromatic = false
    var debug = false

    /// Kayıtlı değerler; eksik, yanlış tipte ya da aralık dışı olanlar varsayılana döner.
    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        var p = Preferences()
        if let v = defaults.object(forKey: Key.enabled) as? Bool { p.enabled = v }
        if let v = defaults.object(forKey: Key.intensity) as? Double, intensityRange.contains(v) { p.intensity = v }
        if let v = defaults.object(forKey: Key.skipFullScreen) as? Bool { p.skipFullScreen = v }
        if let v = defaults.object(forKey: Key.chromatic) as? Bool { p.chromatic = v }
        if let v = defaults.object(forKey: Key.debug) as? Bool { p.debug = v }
        return p
    }
}
