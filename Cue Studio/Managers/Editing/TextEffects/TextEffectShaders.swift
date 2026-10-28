//
//  TextEffectShaders.swift
//  Cue Studio
//

/// The GPU programs that draw a text effect's frame (`TextEffectRenderer`), compiled by the system the first time an effect
/// is painted (in a few milliseconds, once per launch), so building the app needs no Metal toolchain.
nonisolated enum TextEffectShaders {
    static let source = """
        #include <metal_stdlib>
        using namespace metal;

        /// A corner of a quad in the drawing's pixels (from the bottom left, y up) and where it reads its image (from the top left).
        struct Corner {
            float2 position;
            float2 uv;
        };

        struct Fragment {
            float4 position [[position]];
            float2 uv;
        };

        /// What a quad's pixels are multiplied by (its opacity on all four, or a fill's color) and the stretch of the target, in
        /// pixels from its top left, it is cut to (a pixel the edge crosses keeps the part inside, as Core Image crops).
        struct Look {
            float4 tint;
            float4 clip;
        };

        vertex Fragment textEffectVertex(uint vertexID [[vertex_id]], constant Corner *quad [[buffer(0)]], constant float2 &size [[buffer(1)]]) {
            Corner corner = quad[vertexID];
            Fragment out;
            out.position = float4(corner.position / size * 2 - 1, 0, 1);
            out.uv = corner.uv;
            return out;
        }

        /// How much of the pixel centered on `pixel` is inside `clip`.
        static float coverage(float2 pixel, float4 clip) {
            float2 overlap = clamp(min(pixel + 0.5, clip.zw) - max(pixel - 0.5, clip.xy), 0.0, 1.0);
            return overlap.x * overlap.y;
        }

        static float linearized(float value) {
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
        }

        /// A painted piece's pixel (sRGB, premultiplied, as Core Graphics drew it) in linear light, premultiplied: what Core Image
        /// blends in.
        static float4 painted(texture2d<float> image, float2 uv) {
            constexpr sampler bilinear(filter::linear, address::clamp_to_zero);
            float4 color = image.sample(bilinear, uv);
            if (color.a <= 0) {
                return float4(0);
            }
            float3 straight = color.rgb / color.a;
            return float4(float3(linearized(straight.r), linearized(straight.g), linearized(straight.b)) * color.a, color.a);
        }

        fragment float4 textEffectSprite(Fragment in [[stage_in]], texture2d<float> image [[texture(0)]], constant Look &look [[buffer(0)]]) {
            float covered = coverage(in.position.xy, look.clip);
            if (covered <= 0) {
                discard_fragment();
            }
            return painted(image, in.uv) * look.tint * covered;
        }

        /// A band of light that shows only where the faces drawn into `faces` are.
        fragment float4 textEffectMaskedSprite(
            Fragment in [[stage_in]], texture2d<float> image [[texture(0)]], texture2d<float> faces [[texture(1)]], constant Look &look [[buffer(0)]]
        ) {
            float covered = coverage(in.position.xy, look.clip);
            if (covered <= 0) {
                discard_fragment();
            }
            return painted(image, in.uv) * look.tint * covered * faces.read(uint2(in.position.xy)).a;
        }

        /// A rect, its edges' pixels as covered as they are: its quad reaches a pixel past it, its clip is the rect itself.
        fragment float4 textEffectFill(Fragment in [[stage_in]], constant Look &look [[buffer(0)]]) {
            float covered = coverage(in.position.xy, look.clip);
            if (covered <= 0) {
                discard_fragment();
            }
            return look.tint * covered;
        }
        """
}
