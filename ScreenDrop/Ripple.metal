#include <metal_stdlib>
using namespace metal;

// Ek yeri dalgası (seam-ripple-prompt.md, Faz 4): yalnızca yakalanan görüntünün piksellerini kaydırır.
// Işık, halka, renk ya da şekil eklenmez. Hesap global noktalarda yapılır; böylece iki ekrandaki şeritler
// aynı dalgayı kesintisiz paylaşır.

// Swift'teki `RippleUniforms` ile birebir aynı düzen (72 bayt).
struct RippleUniforms {
    float2 stripOrigin;   // şeridin global sol üstü (pt)
    float2 stripSize;     // pt
    float2 crossing;      // geçiş noktası C, global (pt)
    float time;           // tetiklemeden beri saniye
    float amplitude;      // pt
    float speed;          // pt/sn
    float width;          // pt
    float wavelength;     // pt
    float tau;            // sn
    float seamPosition;   // dikey ekte x, yatayda y
    float duration;       // sn; bu anda kayma tam sıfır
    int seamVertical;
    int seamEdge;         // 0 sol, 1 sağ, 2 üst, 3 alt: solma uygulanmayan kenar
    int chromatic;
    int debug;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;            // sol üst (0,0), sağ alt (1,1)
};

vertex VertexOut rippleVertex(uint id [[vertex_id]]) {
    float2 corner = float2(id & 1, id >> 1);   // üçgen şeridi: (0,0) (1,0) (0,1) (1,1)
    VertexOut out;
    out.position = float4(corner.x * 2.0 - 1.0, 1.0 - corner.y * 2.0, 0.0, 1.0);
    out.uv = corner;
    return out;
}

static float hash31(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

// Yumuşak değer gürültüsü, [-1, 1].
static float valueNoise(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    float3 u = f * f * (3.0 - 2.0 * f);
    float n = mix(mix(mix(hash31(i), hash31(i + float3(1, 0, 0)), u.x),
                      mix(hash31(i + float3(0, 1, 0)), hash31(i + float3(1, 1, 0)), u.x), u.y),
                  mix(mix(hash31(i + float3(0, 0, 1)), hash31(i + float3(1, 0, 1)), u.x),
                      mix(hash31(i + float3(0, 1, 1)), hash31(i + float3(1, 1, 1)), u.x), u.y), u.z);
    return n * 2.0 - 1.0;
}

fragment half4 rippleFragment(VertexOut in [[stage_in]],
                              texture2d<half> source [[texture(0)]],
                              constant RippleUniforms &u [[buffer(0)]]) {
    float2 local = in.uv * u.stripSize;
    float2 p = u.stripOrigin + local;
    float2 delta = p - u.crossing;
    float d = length(delta);
    float2 dir = d > 0.001 ? delta / d : float2(0.0, 1.0);
    float t = u.time;

    float r = u.speed * t;
    float front = exp(-pow(d - r, 2.0) / (2.0 * u.width * u.width));
    // Belgedeki sönüm; son %30'da tam sıfıra iner ki overlay kalkınca hiçbir sıçrama olmasın.
    float decay = exp(-t / u.tau) * (1.0 - smoothstep(u.duration * 0.7, u.duration, t));
    float k = 6.28318 / u.wavelength;
    float2 displacement = dir * u.amplitude * sin(k * (d - r)) * front * decay;
    // Jöle hissi: dalgaya dik, organik bir kıpırtı.
    float wobble = valueNoise(float3(p * 0.02, t * 6.0));
    displacement += float2(-dir.y, dir.x) * u.amplitude * 0.35 * wobble * front * decay;

    float toSeam = u.seamVertical != 0 ? abs(p.x - u.seamPosition) : abs(p.y - u.seamPosition);
    displacement *= 1.0 + 0.6 * exp(-toSeam / 60.0);

    // Ek yeri dışındaki her kenarda 40 pt içinde tam sıfır: aksi halde şeridin dikdörtgeni görünür.
    float mask = 1.0;
    if (u.seamEdge != 0) mask *= smoothstep(0.0, 40.0, local.x);
    if (u.seamEdge != 1) mask *= smoothstep(0.0, 40.0, u.stripSize.x - local.x);
    if (u.seamEdge != 2) mask *= smoothstep(0.0, 40.0, local.y);
    if (u.seamEdge != 3) mask *= smoothstep(0.0, 40.0, u.stripSize.y - local.y);
    displacement *= mask;

    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 offset = displacement / u.stripSize;
    half4 color = source.sample(s, in.uv + offset);
    if (u.chromatic != 0) {
        color.r = source.sample(s, in.uv + offset * 1.04).r;
        color.b = source.sample(s, in.uv + offset * 0.96).b;
    }

    if (u.debug != 0) {
        float edge = min(min(local.x, u.stripSize.x - local.x), min(local.y, u.stripSize.y - local.y));
        if (edge < 2.0 || d < 6.0) color = half4(1.0, 0.0, 0.0, 1.0);
    }
    return color;
}
