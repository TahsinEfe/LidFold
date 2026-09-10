import Foundation

/// The Metal source is compiled at launch with `makeLibrary(source:)` rather than
/// shipped as a `.metallib`. SwiftPM would put the compiled library in a resource
/// bundle, which the hand-assembled `.app` would then have to carry and look up; a
/// string keeps the bundle to a single executable.
enum FoldShader {
    static let functionNames = (vertex: "foldVertex", fragment: "foldFragment")

    static let source = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct FoldUniforms {
        float foldDelta;
        float aspectRatio;
        float blurStrength;
        float planeInset;
        int projection;
    };

    // The held plane stays readable; the blur belongs around it, not on it.
    constant float contentBlurFraction = 0.32;
    // The surround is the same desktop, pushed back rather than reprinted at full
    // strength, so it reads as depth instead of a second copy of the content.
    constant float surroundDim = 0.82;

    struct VertexOut {
        float4 position [[position]];
        float2 uv;
    };

    // Full-screen triangle, so no vertex buffer is needed.
    vertex VertexOut foldVertex(uint vertexID [[vertex_id]]) {
        float2 corner = float2((vertexID << 1) & 2, vertexID & 2);
        VertexOut out;
        out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
        out.uv = float2(corner.x, 1.0 - corner.y);
        return out;
    }

    // The hinge sits at y = 0, units are screen heights and the viewer is assumed to be
    // stationary. Parallel projection cancels the tilt without keystone taper; the
    // perspective mode uses a finite eye position and is deliberately more dramatic.
    static float2 projectedCoordinate(float2 uv, float angle, float aspectRatio, int projection) {
        if (projection == 0) {
            return uv;
        }
        float height = 1.0 - uv.y;
        const float3 eye = float3(0.0, 0.65, 1.6);
        float3 surface = float3((uv.x - 0.5) * aspectRatio, height * cos(angle), height * sin(angle));
        float travel = projection == 2 ? eye.z / max(0.25, eye.z - surface.z) : 1.0;
        float3 hit = eye + travel * (surface - eye);
        return float2(hit.x / aspectRatio + 0.5, 1.0 - hit.y);
    }

    // Blur grows with the fold and with distance from the hinge, so the top of the
    // panel smears while the bottom stays legible.
    static float blurRadius(float uvY, float angle, float strength) {
        float height = 1.0 - uvY;
        return strength * smoothstep(0.08, 1.0, height) * abs(sin(angle)) * 65.0;
    }

    // Blending pre-blurred Gaussian levels avoids the repeated edges and speckling that
    // sparse disc sampling produces at large radii.
    static float3 blendLevels(float radius, float2 uv, sampler s,
                              texture2d<float> sharp,
                              texture2d<float> level1,
                              texture2d<float> level2,
                              texture2d<float> level3,
                              texture2d<float> level4) {
        if (radius < 2.0) {
            return mix(sharp.sample(s, uv).rgb, level1.sample(s, uv).rgb, radius / 2.0);
        }
        if (radius < 6.0) {
            return mix(level1.sample(s, uv).rgb, level2.sample(s, uv).rgb, (radius - 2.0) / 4.0);
        }
        if (radius < 16.0) {
            return mix(level2.sample(s, uv).rgb, level3.sample(s, uv).rgb, (radius - 6.0) / 10.0);
        }
        return mix(level3.sample(s, uv).rgb, level4.sample(s, uv).rgb, clamp((radius - 16.0) / 24.0, 0.0, 1.0));
    }

    // Without this the blurred image would still end in a razor-sharp rectangle. Three
    // sigma either side approximates the Gaussian falloff at the image boundary.
    static float edgeCoverage(float2 uv, float radius, float2 sourceSize, float2 derivative) {
        float sigmaPixels = radius * sourceSize.y / 1000.0;
        float2 feather = max(3.0 * sigmaPixels / sourceSize, derivative);
        float2 coverage = smoothstep(-feather, feather, uv)
                        * (1.0 - smoothstep(1.0 - feather, 1.0 + feather, uv));
        return coverage.x * coverage.y;
    }

    // Closing the lid pulls the plane away, so it covers less of the panel. Sampling a
    // wider region of the source shrinks the content towards the centre and leaves room
    // for the surround.
    static float2 shrinkTowardsCentre(float2 uv, float angle, float planeInset) {
        float expand = 1.0 + planeInset * abs(sin(angle));
        return (uv - 0.5) * expand + 0.5;
    }

    fragment float4 foldFragment(VertexOut in [[stage_in]],
                                 texture2d<float> sharp [[texture(0)]],
                                 texture2d<float> level1 [[texture(1)]],
                                 texture2d<float> level2 [[texture(2)]],
                                 texture2d<float> level3 [[texture(3)]],
                                 texture2d<float> level4 [[texture(4)]],
                                 constant FoldUniforms &uniforms [[buffer(0)]]) {
        constexpr sampler linearSampler(filter::linear, address::clamp_to_edge);

        float angle = clamp(uniforms.foldDelta, -0.65, 1.25);
        float aspectRatio = max(0.001, uniforms.aspectRatio);
        float2 uv = projectedCoordinate(in.uv, angle, aspectRatio, uniforms.projection);
        uv = shrinkTowardsCentre(uv, angle, uniforms.planeInset);

        float radius = blurRadius(in.uv.y, angle, uniforms.blurStrength) * contentBlurFraction;
        float3 colour = blendLevels(radius, uv, linearSampler, sharp, level1, level2, level3, level4);

        float2 sourceSize = float2(sharp.get_width(), sharp.get_height());
        float mask = edgeCoverage(uv, radius, sourceSize, fwidth(uv));

        // With blur switched off there is nothing to fill the surround with that would not
        // read as a second, wrongly placed desktop, so it stays dark.
        float3 surround = uniforms.blurStrength > 0.0
            ? level4.sample(linearSampler, in.uv).rgb * surroundDim
            : float3(0.02, 0.035, 0.05);

        return float4(mix(surround, colour, mask), 1.0);
    }
    """#
}
