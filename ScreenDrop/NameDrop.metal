#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// iPhone NameDrop efektinin Mac uyarlaması. Katmanlar ve sıralama MartinRGB'nin kare kare analizinden
// (martinrgb.github.io/blog/#/Namedrop_Animation) ve Apple'ın tanıtım videosundan; kod bizim.
//
// charge:     imleç ortak kenara yaklaştıkça 0 → 1 (toplanma evresi).
// burst:      geçişten beri geçen saniye; < 0 ise patlama yok.
// normal:     kenardan bu ekranın içine doğru birim vektör.
// ring:       1 AirDrop (ilk tasarım: belirgin ışık diski, yanardöner halka, mercek kırılması),
//             0 NameDrop (kenarsız ışık bulutu, tüm ekrana yayılan çizgisiz su dalgası).
// brightness: ışığın çarpanı, 1 varsayılan.

// Patlama 0,9 sn sürer; su dalgası tüm ekranı geçebilsin diye 1,4 sn.
constant float BURST = 1.4;
constant float WAVE_SPEED = 2400.0;   // pt/sn

static float hash11(float n) { return fract(sin(n * 127.1) * 43758.5453); }

static float easeOutCubic(float x) {
    x = clamp(x, 0.0, 1.0);
    return 1.0 - pow(1.0 - x, 3.0);
}

// AirDrop halkasının yansıması: mavi → mor → pembe, beyaza yakın pastel.
static half3 iridescent(float h) {
    float k = 0.5 + 0.5 * sin(6.28318 * h);
    float3 c = k < 0.5 ? mix(float3(0.45, 0.65, 1.0), float3(0.72, 0.55, 1.0), k * 2.0)
                       : mix(float3(0.72, 0.55, 1.0), float3(1.0, 0.62, 0.82), k * 2.0 - 1.0);
    return half3(mix(float3(1.0), c, 0.6));
}

// Çizgisi ya da rengi olmayan su dalgası: t saniyede merkezden WAVE_SPEED ile uzaklaşan, sönümlenen kıpırtı.
static float waterWave(float dist, float t) {
    if (t < 0.0 || t >= BURST) return 0.0;
    float diff = dist - WAVE_SPEED * t;
    float envelope = exp(-(diff * diff) / (2.0 * 150.0 * 150.0));
    float fade = pow(1.0 - t / BURST, 1.5) / (1.0 + dist / 1400.0);
    return sin(diff * 6.28318 / 130.0) * envelope * fade;
}

[[ stitchable ]] half4 nameDrop(float2 position, SwiftUI::Layer layer, texture2d<half> blurTex,
                                float2 size, float2 origin, float2 normal,
                                float charge, float burst, float hasImage, float ring, float brightness) {
    bool airDrop = ring > 0.5;
    float2 d = position - origin;
    float dist = length(d);
    float2 dir = dist > 0.001 ? d / dist : normal;
    float depth = max(dot(d, normal), 0.0);
    float along = dot(d, float2(-normal.y, normal.x));
    float alongFalloff = exp(-along * along / (2.0 * 560.0 * 560.0));

    float c = clamp(charge, 0.0, 1.0);
    float t = burst;
    bool bursting = t >= 0.0 && t < BURST;
    float p = bursting ? min(t / 0.9, 1.0) : 1.0;    // ışık, bulanıklık ve esneme 0,9 sn'de biter

    // 1. Esneme: içerik kenara doğru çekilir, patlamada yaylanarak geri bırakılır.
    float bounce = bursting ? sin(3.14159 * min(1.0, t / 0.35)) * (1.0 - p) : 0.0;
    float pull = (c * c * 22.0 - bounce * 14.0) * exp(-depth / 240.0) * alongFalloff;
    float2 offset = normal * pull;

    // 2. AirDrop: ışık diskinin kenarının biraz gerisinde mercek gibi kırılma.
    //    NameDrop: çizgisi ya da rengi olmayan, yalnızca içeriği dalgalandırarak tüm ekrana yayılan su dalgası.
    float R = 40.0 + 520.0 * easeOutCubic(t / 0.6);
    float wave = 0.0;
    if (airDrop) {
        if (bursting) {
            float diff = dist - R * 0.9;
            float band = exp(-(diff * diff) / (2.0 * 45.0 * 45.0));
            offset -= dir * diff * band * 0.4 * pow(1.0 - p, 2.0);
        }
    } else {
        wave = waterWave(dist, t);
        offset += dir * wave * 9.0;
    }
    // Görüntünün dışı boş; dışarıdan örneklemek kenarda siyah çizgi bırakır.
    float2 sp = clamp(position + offset, float2(0.5), size - 0.5);
    half4 sharp = layer.sample(sp);

    // 3. Bulanıklık: kenara yaklaştıkça artar; patlamada disk içinde güçlenip çözülür.
    float gatherBlur = c * exp(-depth / 380.0) * alongFalloff;
    float inside = !bursting ? 0.0
                 : airDrop ? 1.0 - smoothstep(R * 0.7, R * 1.05, dist)
                           : 1.0 - smoothstep(R * 0.45, R * 1.15, dist);
    float burstBlur = inside * (1.0 - smoothstep(0.3, 0.85, p));
    float blurAmt = clamp(max(gatherBlur * 1.3, burstBlur), 0.0, 1.0) * hasImage;
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    half4 col = mix(sharp, blurTex.sample(s, sp / size), half(blurAmt));

    // 4. Işık: kenarda biriken beyaz parıltı ve patlamada büyüyen beyaz ışık (AirDrop'ta disk, NameDrop'ta kenarsız bulut).
    float glow = pow(c, 1.6) * exp(-dist / (80.0 + 220.0 * c)) * 1.25
               + c * c * exp(-depth / 90.0) * exp(-along * along / (2.0 * 380.0 * 380.0)) * 0.65;  // kenar boyunca beyaz sis
    float flash = bursting ? 1.0 - smoothstep(0.12, 0.7, p) : 0.0;
    float disc = airDrop ? inside * flash * mix(1.0, 0.45, clamp(dist / R, 0.0, 1.0))
                         : flash * exp(-pow(dist / (R * 0.62), 2.0)) * 1.15;
    float shimmer = max(wave, 0.0) * 0.06;   // dalganın üstünde hafif ışık yansıması
    float halo = 0.0;
    float hue = 0.0;
    if (airDrop && bursting) {
        float width = 26.0 + 30.0 * p;
        halo = exp(-pow((dist - R) / width, 2.0)) * pow(1.0 - p, 1.3);
        hue = atan2(d.y, d.x) / 6.28318 * 0.6 + dist * 0.0015 + t * 0.5;
    }

    // 5. Parçacıklar: temas noktasından ekranın içine fırlayan ince ışık çizgileri.
    float sparks = 0.0;
    if (bursting && t < 0.7) {
        float base = atan2(normal.y, normal.x);
        for (int i = 0; i < 32; i++) {
            float fi = float(i);
            float life = 0.45 + 0.25 * hash11(fi + 31.0);
            float k = t / life;
            if (k >= 1.0) continue;
            float ang = base + (hash11(fi) - 0.5) * 2.6;
            float2 v = float2(cos(ang), sin(ang));
            float head = (260.0 + 520.0 * hash11(fi + 17.0)) * life * easeOutCubic(k);
            float len = 14.0 + 26.0 * hash11(fi + 7.0);
            float a = dot(d, v);
            float perp = length(d - v * a);
            sparks += step(head - len, a) * step(a, head) * smoothstep(1.6, 0.2, perp) * (1.0 - k) * (1.0 - k);
        }
    }

    float b = max(brightness, 0.0);
    float whiten = clamp((disc + glow + shimmer) * b, 0.0, 1.0);
    float lines = sparks * 0.6 * b;
    float rim = halo * 0.85 * b;
    col.rgb += (half3(col.a) - col.rgb) * half(whiten);  // screen blend (premultiplied)
    col.rgb += half3(whiten) * (1.0h - col.a);            // şeffaf katmanda da beyaz görünsün
    col.rgb += iridescent(hue) * half(rim);
    col.rgb += half3(lines);
    col.a = max(col.a, half(clamp(whiten + rim + lines, 0.0, 1.0)));
    return col;
}
