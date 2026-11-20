import WGPUKit

/// A 2D texture with its default view. Not reference counted: whoever made it calls `release()`.
public struct GPUTexture2D {
    public let texture: WGPUTexture
    public let view: WGPUTextureView
    public let width: Int
    public let height: Int
    public let format: WGPUTextureFormat

    public init(texture: WGPUTexture, view: WGPUTextureView, width: Int, height: Int, format: WGPUTextureFormat) {
        self.texture = texture; self.view = view; self.width = width; self.height = height; self.format = format
    }

    public static func make(device: WGPUDevice, width: Int, height: Int, format: WGPUTextureFormat, usage: WGPUTextureUsage) -> GPUTexture2D? {
        var descriptor = WGPUTextureDescriptor()
        descriptor.usage = usage
        descriptor.dimension = WGPUTextureDimension_2D
        descriptor.size = WGPUExtent3D(width: UInt32(width), height: UInt32(height), depthOrArrayLayers: 1)
        descriptor.format = format
        descriptor.mipLevelCount = 1
        descriptor.sampleCount = 1
        guard let texture = wgpuDeviceCreateTexture(device, &descriptor) else { return nil }
        guard let view = wgpuTextureCreateView(texture, nil) else { wgpuTextureRelease(texture); return nil }
        return GPUTexture2D(texture: texture, view: view, width: width, height: height, format: format)
    }

    public func release() {
        wgpuTextureViewRelease(view)
        wgpuTextureRelease(texture)
    }

    /// Clears the texture to transparent black (it needs the RenderAttachment usage).
    public func clear(context: WGPUSharedContext) {
        guard let encoder = wgpuDeviceCreateCommandEncoder(context.device, nil) else { return }
        var attachment = WGPURenderPassColorAttachment()
        attachment.view = view
        attachment.depthSlice = UInt32.max
        attachment.loadOp = WGPULoadOp_Clear
        attachment.storeOp = WGPUStoreOp_Store
        attachment.clearValue = WGPUColor(r: 0, g: 0, b: 0, a: 0)
        withUnsafePointer(to: &attachment) { pointer in
            var descriptor = WGPURenderPassDescriptor()
            descriptor.colorAttachmentCount = 1
            descriptor.colorAttachments = pointer
            if let pass = wgpuCommandEncoderBeginRenderPass(encoder, &descriptor) {
                wgpuRenderPassEncoderEnd(pass)
                wgpuRenderPassEncoderRelease(pass)
            }
        }
        if let commands = wgpuCommandEncoderFinish(encoder, nil) {
            var submitted: WGPUCommandBuffer? = commands
            withUnsafePointer(to: &submitted) { wgpuQueueSubmit(context.queue, 1, $0) }
            wgpuCommandBufferRelease(commands)
        }
        wgpuCommandEncoderRelease(encoder)
    }

    /// Writes 4-byte pixels (`width * height * 4` bytes, first row at the top) through the queue (needs the CopyDst usage).
    public func upload(pixels: [UInt8], context: WGPUSharedContext) {
        var copy = WGPUTexelCopyTextureInfo()
        copy.texture = texture
        var layout = WGPUTexelCopyBufferLayout()
        layout.bytesPerRow = UInt32(width * 4)
        layout.rowsPerImage = UInt32(height)
        var extent = WGPUExtent3D(width: UInt32(width), height: UInt32(height), depthOrArrayLayers: 1)
        var bytes = pixels
        bytes.withUnsafeMutableBytes { wgpuQueueWriteTexture(context.queue, &copy, $0.baseAddress, $0.count, &layout, &extent) }
    }
}

/// A buffer of `size` bytes, or nil when the device cannot make it.
public func makeGPUBuffer(device: WGPUDevice, size: Int, usage: WGPUBufferUsage) -> WGPUBuffer? {
    var descriptor = WGPUBufferDescriptor()
    descriptor.size = UInt64(size)
    descriptor.usage = usage
    return wgpuDeviceCreateBuffer(device, &descriptor)
}
