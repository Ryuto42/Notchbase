#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

static float roundedRectSDF(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + float2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, float2(0.0))) - r;
}

static float bevelHeight(float d, float zRadius) {
    if (d <= 0.0) return 0.0;
    if (d >= zRadius) return zRadius;
    return sqrt(d * (2.0 * zRadius - d));
}

[[ stitchable ]] half4 liquidGlass(float2 position,
                                   float4 bounds,
                                   float radius,
                                   float zRadius,
                                   float edgeHighlight,
                                   float specular,
                                   float fresnel,
                                   float body) {
    float2 halfSize = bounds.zw * 0.5;
    float2 p = position - (bounds.xy + halfSize);
    float r = min(radius, min(halfSize.x, halfSize.y));
    float sdf = roundedRectSDF(p, halfSize, r);
    if (sdf > 0.5) return half4(0.0);

    float mask = 1.0 - smoothstep(-1.5, 0.5, sdf);
    float inside = -sdf;
    float maxD = min(halfSize.x, halfSize.y);
    float edge = smoothstep(maxD * 0.35, 0.0, inside);
    float zR = min(zRadius, maxD);

    float e = 1.5;
    float hR = bevelHeight(-roundedRectSDF(p + float2(e, 0.0), halfSize, r), zR);
    float hL = bevelHeight(-roundedRectSDF(p - float2(e, 0.0), halfSize, r), zR);
    float hU = bevelHeight(-roundedRectSDF(p + float2(0.0, e), halfSize, r), zR);
    float hD = bevelHeight(-roundedRectSDF(p - float2(0.0, e), halfSize, r), zR);
    float2 gradient = float2(hR - hL, hU - hD) / (2.0 * e);
    float3 n = normalize(float3(-gradient, 1.0));
    float depth = smoothstep(0.0, zR, inside);

    float fres = pow(1.0 - abs(n.z), 4.0) * fresnel;

    float3 v = float3(0.0, 0.0, 1.0);
    float3 l1 = normalize(float3(0.4, 0.7, 1.0));
    float3 l2 = normalize(float3(-0.3, -0.5, 1.0));
    float3 l3 = normalize(float3(0.1, 0.3, 1.0));
    float3 l4 = normalize(float3(0.0, 0.9, 0.4));
    float spec = pow(max(dot(n, normalize(l1 + v)), 0.0), 90.0)
               + pow(max(dot(n, normalize(l2 + v)), 0.0), 50.0) * 0.3
               + pow(max(dot(n, l3), 0.0), 6.0) * 0.1
               + pow(max(dot(n, normalize(l4 + v)), 0.0), 120.0) * 0.6;
    spec *= specular;

    float stroke = smoothstep(-2.5, -1.5, sdf) * (1.0 - smoothstep(-1.0, 0.0, sdf));
    float topBias = 0.5 + 0.5 * (-p.y / max(halfSize.y, 1.0));
    stroke *= 0.4 + 0.6 * clamp(topBias, 0.0, 1.0);

    float rim = edge * edgeHighlight * 0.22;
    float glow = smoothstep(5.0, 0.0, inside) * edgeHighlight * 0.15;
    float reflection = (n.y * 0.5 + 0.5) * fres * 0.08;

    float light = spec + rim + glow + stroke * edgeHighlight * 0.55 + reflection + fres * 0.2;
    float alpha = clamp(body * (1.0 + 0.06 * depth) + light, 0.0, 1.0) * mask;
    return half4(half3(alpha), half(alpha));
}
