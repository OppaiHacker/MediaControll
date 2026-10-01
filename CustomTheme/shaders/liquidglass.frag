#version 440
// Liquid glass: refracts (lenses) the backdrop near the rounded edge, splits
// it into RGB a little (chromatic aberration), softens it, tints it, and adds
// a specular rim lit from the top-left.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // panel size, px
    vec2 origin;      // panel top-left in backdrop px
    vec2 backdropSize;// backdrop size, px
    float radius;
    float bezel;      // width of the refracting edge band, px
    float strength;   // max refraction offset, px
    float aberration; // 0..1 fraction of the offset split between R and B
    float blurRadius; // px
    vec4 tint;        // rgb + amount
    float specular;
};
layout(binding = 1) uniform sampler2D backdrop;

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

vec3 blurred(vec2 px) {
    vec3 c = vec3(0.0);
    float w = 0.0;
    for (int x = -2; x <= 2; x++)
        for (int y = -2; y <= 2; y++) {
            float k = exp(-float(x * x + y * y) / 4.0);
            c += texture(backdrop, (px + vec2(x, y) * blurRadius * 0.5) / backdropSize).rgb * k;
            w += k;
        }
    return c / w;
}

void main() {
    vec2 half_ = size * 0.5;
    vec2 p = qt_TexCoord0 * size;
    vec2 c = p - half_;
    float r = min(radius, min(half_.x, half_.y));
    float d = sdRoundRect(c, half_, r);              // < 0 inside
    float alpha = 1.0 - smoothstep(-1.0, 0.5, d);

    vec2 e = vec2(1.0, 0.0);
    vec2 n = vec2(sdRoundRect(c + e.xy, half_, r) - sdRoundRect(c - e.xy, half_, r),
                  sdRoundRect(c + e.yx, half_, r) - sdRoundRect(c - e.yx, half_, r));
    n = n / max(length(n), 1e-4);                    // outward normal

    // 0 in the flat middle, 1 at the edge; cubic so the lens curls at the rim.
    float t = clamp(1.0 + d / bezel, 0.0, 1.0);
    float bend = t * t * t * strength;
    vec2 base = origin + p;

    vec3 col;
    col.r = blurred(base - n * bend * (1.0 + aberration)).r;
    col.g = blurred(base - n * bend).g;
    col.b = blurred(base - n * bend * (1.0 - aberration)).b;

    col = mix(col, tint.rgb, tint.a);
    col += t * t * 0.07;                             // light gathering in the bezel

    float rim = 1.0 - smoothstep(0.0, 2.5, -d);
    vec2 light = normalize(vec2(-0.55, -0.85));
    float spec = pow(max(dot(n, light), 0.0), 2.0) + 0.45 * pow(max(dot(n, -light), 0.0), 2.0);
    col += rim * spec * specular;

    fragColor = vec4(col, 1.0) * alpha * qt_Opacity;
}
