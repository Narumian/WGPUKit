import Foundation
import WGPUKit

/// Copies a texture back to the CPU through a staging buffer. One readback holds one in-flight copy: `request` returns false while an
/// earlier one has not been delivered. Maps are delivered when the device is polled (`poll()`, or the blocking `read`).
public final class GPUReadback: @unchecked Sendable {
    public let width: Int
    public let height: Int
    public let bytesPerPixel: Int
    private let context: WGPUSharedContext
    private let staging: WGPUBuffer
    private let bytesPerRow: Int
    private let lock = NSLock()
    private var busy = false

    /// A readback for textures of exactly `width` x `height` with `bytesPerPixel` (RGBA8 4, RGBA16F 8, RGBA32F 16).
    public init?(context: WGPUSharedContext, width: Int, height: Int, bytesPerPixel: Int) {
        guard width > 0, height > 0, bytesPerPixel > 0 else { return nil }
        let rowBytes = (width * bytesPerPixel + 255) / 256 * 256
        guard let staging = makeGPUBuffer(device: context.device, size: rowBytes * height,
                                          usage: WGPUBufferUsage_MapRead | WGPUBufferUsage_CopyDst) else { return nil }
        self.context = context
        self.width = width
        self.height = height
        self.bytesPerPixel = bytesPerPixel
        self.staging = staging
        self.bytesPerRow = rowBytes
    }

    deinit { wgpuBufferRelease(staging) }

    /// Starts a copy of `texture` and delivers its bytes (`width * height * bytesPerPixel`, rows tight, first row first) to `completion`
    /// once the GPU has finished and the device has been polled; nil when the map failed. False when a copy is already in flight.
    /// The completion may run on whichever thread polls.
    @discardableResult
    public func request(texture: WGPUTexture, completion: @escaping @Sendable ([UInt8]?) -> Void) -> Bool {
        lock.lock()
        if busy { lock.unlock(); return false }
        busy = true
        lock.unlock()

        guard let encoder = wgpuDeviceCreateCommandEncoder(context.device, nil) else { release(); completion(nil); return true }
        var source = WGPUTexelCopyTextureInfo()
        source.texture = texture
        var destination = WGPUTexelCopyBufferInfo()
        destination.buffer = staging
        destination.layout.bytesPerRow = UInt32(bytesPerRow)
        destination.layout.rowsPerImage = UInt32(height)
        var extent = WGPUExtent3D(width: UInt32(width), height: UInt32(height), depthOrArrayLayers: 1)
        wgpuCommandEncoderCopyTextureToBuffer(encoder, &source, &destination, &extent)
        let commands = wgpuCommandEncoderFinish(encoder, nil)
        wgpuCommandEncoderRelease(encoder)
        guard let commands else { release(); completion(nil); return true }
        var submitted: WGPUCommandBuffer? = commands
        withUnsafePointer(to: &submitted) { wgpuQueueSubmit(context.queue, 1, $0) }
        wgpuCommandBufferRelease(commands)

        var info = WGPUBufferMapCallbackInfo()
        info.mode = WGPUCallbackMode_AllowSpontaneous
        info.callback = { status, _, userdata, _ in
            let pending = Unmanaged<Pending>.fromOpaque(userdata!).takeRetainedValue()
            pending.readback.delivered(success: status == WGPUMapAsyncStatus_Success, completion: pending.completion)
        }
        info.userdata1 = Unmanaged.passRetained(Pending(readback: self, completion: completion)).toOpaque()
        _ = wgpuBufferMapAsync(staging, WGPUMapMode_Read, 0, bytesPerRow * height, info)
        return true
    }

    /// Polls the device so that finished maps are delivered.
    public func poll() { _ = wgpuDevicePoll(context.device, 0, nil) }

    /// Copies `texture` and waits for the GPU: for tests and tools. Nil when the copy failed, timed out or another copy is in flight.
    public func read(texture: WGPUTexture) -> [UInt8]? {
        final class Result: @unchecked Sendable { var bytes: [UInt8]? }
        let result = Result()
        let done = DispatchSemaphore(value: 0)
        guard request(texture: texture, completion: { result.bytes = $0; done.signal() }) else { return nil }
        var spins = 0
        while done.wait(timeout: .now()) != .success {
            _ = wgpuDevicePoll(context.device, 1, nil)
            spins += 1
            if spins > 20_000 { return nil }
        }
        return result.bytes
    }

    private final class Pending {
        let readback: GPUReadback
        let completion: @Sendable ([UInt8]?) -> Void
        init(readback: GPUReadback, completion: @escaping @Sendable ([UInt8]?) -> Void) { self.readback = readback; self.completion = completion }
    }

    private func release() { lock.lock(); busy = false; lock.unlock() }

    private func delivered(success: Bool, completion: @Sendable ([UInt8]?) -> Void) {
        var out: [UInt8]?
        if success, let pointer = wgpuBufferGetConstMappedRange(staging, 0, bytesPerRow * height) {
            let rowLength = width * bytesPerPixel
            var bytes = [UInt8](repeating: 0, count: rowLength * height)
            let base = pointer.assumingMemoryBound(to: UInt8.self)
            bytes.withUnsafeMutableBytes { target in
                for row in 0..<height {
                    target.baseAddress!.advanced(by: row * rowLength).copyMemory(from: base + row * bytesPerRow, byteCount: rowLength)
                }
            }
            out = bytes
            wgpuBufferUnmap(staging)
        }
        release()
        completion(out)
    }
}
