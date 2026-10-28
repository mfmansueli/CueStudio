//
//  TextEffectRenderer.swift
//  Cue Studio
//

import CoreGraphics
import CoreImage
import Metal

/// Draws a text effect's frame on the GPU (`TextEffectComposer`): every quad of it in one pass, in linear light like Core
/// Image, a band of light shown only over the faces drawn first into a texture of their own. The frame comes back as one
/// image for the video's compositor, the same in the preview and the export. A frame of any of the six costs the iPhone 15
/// Pro 1.4 to 3 ms; Core Image putting the same pieces together as a graph of images took up to 25 ms, mostly compiling a
/// new graph on every frame, and three effects coming in at once played at 25 frames a second instead of 67
/// (`TextEffectDeviceTests`).
nonisolated final class TextEffectRenderer: @unchecked Sendable {
    /// Nil only where there is no Metal: the effects then draw nothing.
    static let shared = TextEffectRenderer()

    private static let linear = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? TextEffectPainter.colorSpace
    private static let format = MTLPixelFormat.rgba16Float

    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let sprite: MTLRenderPipelineState
    private let masked: MTLRenderPipelineState
    private let fill: MTLRenderPipelineState

    private init?() {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = try? device.makeLibrary(source: TextEffectShaders.source, options: nil),
              let sprite = Self.pipeline(device, library, fragment: "textEffectSprite"),
              let masked = Self.pipeline(device, library, fragment: "textEffectMaskedSprite"),
              let fill = Self.pipeline(device, library, fragment: "textEffectFill") else { return nil }
        self.device = device
        self.queue = queue
        self.sprite = sprite
        self.masked = masked
        self.fill = fill
    }

    /// Gets the GPU programs ready away from the main thread, so the first effect a gesture picks up doesn't wait for them:
    /// the first time after an install the system compiles them (about half a second on an iPhone 15 Pro), then keeps them
    /// (about 15 ms at each launch).
    static func prepareInBackground() {
        Task.detached(priority: .utility) { _ = shared }
    }

    /// The bitmap `context` drew (RGBA, premultiplied, sRGB) as a texture.
    func texture(from context: CGContext) -> MTLTexture? {
        guard let data = context.data else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: context.width, height: context.height, mipmapped: false
        )
        descriptor.usage = .shaderRead
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        texture.replace(
            region: MTLRegionMake2D(0, 0, context.width, context.height), mipmapLevel: 0, withBytes: data, bytesPerRow: context.bytesPerRow
        )
        return texture
    }

    /// `draws` over each other on a clear drawing `size` big (from the bottom left, y up); `faces` are what a band of light
    /// shows over.
    func image(size: CGSize, draws: [TextEffectDraw], faces: [TextEffectDraw]) -> CIImage? {
        let width = Int(ceil(size.width))
        let height = Int(ceil(size.height))
        guard width > 0, height > 0, width < 16_384, height < 16_384,
              let target = target(width, height), let buffer = queue.makeCommandBuffer() else { return nil }
        var mask: MTLTexture?
        if draws.contains(where: \.isMasked), !faces.isEmpty, let faceTarget = self.target(width, height) {
            encode(faces, into: faceTarget, mask: nil, buffer)
            mask = faceTarget
        }
        encode(draws, into: target, mask: mask, buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed, let image = CIImage(mtlTexture: target, options: [.colorSpace: Self.linear]) else { return nil }
        // A texture's rows go down from its top; the drawing's y goes up.
        return image.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(height)))
    }

    // MARK: - Private

    private static func pipeline(_ device: MTLDevice, _ library: MTLLibrary, fragment: String) -> MTLRenderPipelineState? {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "textEffectVertex")
        descriptor.fragmentFunction = library.makeFunction(name: fragment)
        guard let color = descriptor.colorAttachments[0] else { return nil }
        color.pixelFormat = format
        // Premultiplied, one over the other.
        color.isBlendingEnabled = true
        color.sourceRGBBlendFactor = .one
        color.sourceAlphaBlendFactor = .one
        color.destinationRGBBlendFactor = .oneMinusSourceAlpha
        color.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func target(_ width: Int, _ height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.format, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private func encode(_ draws: [TextEffectDraw], into target: MTLTexture, mask: MTLTexture?, _ buffer: MTLCommandBuffer) {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var size = SIMD2<Float>(Float(target.width), Float(target.height))
        encoder.setVertexBytes(&size, length: MemoryLayout<SIMD2<Float>>.stride, index: 1)
        for draw in draws {
            // A band of light over no faces shows nowhere.
            if draw.isMasked && mask == nil { continue }
            let pipeline = draw.texture == nil ? fill : draw.isMasked ? masked : sprite
            encoder.setRenderPipelineState(pipeline)
            var corners = draw.corners
            var look = draw.look(height: target.height)
            encoder.setVertexBytes(&corners, length: MemoryLayout<SIMD4<Float>>.stride * corners.count, index: 0)
            encoder.setFragmentBytes(&look, length: MemoryLayout<SIMD4<Float>>.stride * look.count, index: 0)
            if let texture = draw.texture { encoder.setFragmentTexture(texture, index: 0) }
            if draw.isMasked { encoder.setFragmentTexture(mask, index: 1) }
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
        encoder.endEncoding()
    }
}
