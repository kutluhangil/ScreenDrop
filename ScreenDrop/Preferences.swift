import Foundation

enum EffectStyle: String, CaseIterable, Identifiable {
    case airDrop, nameDrop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .airDrop: "AirDrop"
        case .nameDrop: "NameDrop"
        }
    }

    var detail: String {
        switch self {
        case .airDrop: "Parlak ışık diski ve yanardöner halka"
        case .nameDrop: "Kenarsız ışık, ekrana yayılan su dalgası"
        }
    }

    var symbol: String {
        switch self {
        case .airDrop: "circle.circle"
        case .nameDrop: "water.waves"
        }
    }

    /// Shader'da efektin bittiği an, hız 1'de (saniye).
    var duration: Double {
        switch self {
        case .airDrop: 0.95
        case .nameDrop: 1.4
        }
    }
}

/// Ayarlar; görünümler aynı anahtarları @AppStorage ile okur ve yazar.
struct Preferences {
    enum Key {
        static let enabled = "enabled"
        static let style = "style"
        static let brightness = "brightness"
        static let speed = "speed"
        static let gather = "gather"
        static let zone = "zone"
    }

    static let brightnessRange = 0.5...1.6
    static let speedRange = 0.6...1.6
    static let zoneRange = 80.0...320.0

    var enabled = true
    var style = EffectStyle.airDrop
    var brightness = 1.0
    var speed = 1.0
    var gather = true
    var zone = 160.0

    /// Kayıtlı değerler; eksik ya da aralık dışı olanlar varsayılana döner.
    static func load(from defaults: UserDefaults = .standard) -> Preferences {
        var p = Preferences()
        if let v = defaults.object(forKey: Key.enabled) as? Bool { p.enabled = v }
        if let v = defaults.string(forKey: Key.style).flatMap(EffectStyle.init(rawValue:)) { p.style = v }
        if let v = defaults.object(forKey: Key.brightness) as? Double, brightnessRange.contains(v) { p.brightness = v }
        if let v = defaults.object(forKey: Key.speed) as? Double, speedRange.contains(v) { p.speed = v }
        if let v = defaults.object(forKey: Key.gather) as? Bool { p.gather = v }
        if let v = defaults.object(forKey: Key.zone) as? Double, zoneRange.contains(v) { p.zone = v }
        return p
    }
}
