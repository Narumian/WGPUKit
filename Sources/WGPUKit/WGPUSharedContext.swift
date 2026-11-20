import Foundation
@_exported import CWGPU

/// The GPU a renderer draws with, for others to draw on too (a worker thread that renders a preview). wgpu's device and queue
/// are thread-safe, and everything submitted to one queue runs in the order it was submitted, so a worker that submits a picture
/// and only then names its texture to the UI thread can be sure that the frame which draws it sees the finished picture. Nothing
/// waits and nothing is copied through the CPU.
public final class WGPUSharedContext: @unchecked Sendable {
    public let device: WGPUDevice
    public let queue: WGPUQueue

    /// Takes its own references to `device` and `queue`; the caller keeps its own.
    public init(device: WGPUDevice, queue: WGPUQueue) {
        self.owned = []
        wgpuDeviceAddRef(device)
        wgpuQueueAddRef(queue)
        self.device = device
        self.queue = queue
    }

    /// Objects the device depends on that this context keeps alive (a headless context's instance and adapter).
    let owned: [AnyObject]

    init(device: WGPUDevice, queue: WGPUQueue, owning owned: [AnyObject]) {
        self.owned = owned
        wgpuDeviceAddRef(device)
        wgpuQueueAddRef(queue)
        self.device = device
        self.queue = queue
    }

    deinit {
        wgpuQueueRelease(queue)
        wgpuDeviceRelease(device)
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var window: WGPUSharedContext?

    /// The context of the window's renderer (the first one with a surface), or nil before it exists.
    public static var current: WGPUSharedContext? { lock.withLock { window } }

    /// Makes `context` the window's context unless one is already published. The renderer that owns the window calls this.
    public static func publish(_ context: WGPUSharedContext) {
        lock.withLock { if window == nil { window = context } }
    }

    /// Withdraws `context` if it is the published one.
    public static func retire(_ context: WGPUSharedContext) {
        lock.withLock { if window === context { window = nil } }
    }
}
