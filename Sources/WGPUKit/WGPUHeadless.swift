import Foundation

extension WGPUSharedContext {
    /// A GPU of its own, with no window and no surface: for tools, tests and workers that draw offscreen. Takes the default adapter
    /// (the system's best) and a default device. Nil when the machine has no usable adapter.
    ///
    /// The context keeps the instance and adapter alive; it is never published as the window's context.
    public static func makeHeadless() -> WGPUSharedContext? {
        guard let instance = wgpuCreateInstance(nil) else { return nil }
        guard let adapter = requestAdapter(instance: instance) else { wgpuInstanceRelease(instance); return nil }
        guard let device = requestDevice(instance: instance, adapter: adapter) else {
            wgpuAdapterRelease(adapter); wgpuInstanceRelease(instance); return nil
        }
        guard let queue = wgpuDeviceGetQueue(device) else {
            wgpuDeviceRelease(device); wgpuAdapterRelease(adapter); wgpuInstanceRelease(instance); return nil
        }
        let context = WGPUSharedContext(device: device, queue: queue, owning: [Retained(instance: instance, adapter: adapter)])
        // the context took its own references
        wgpuQueueRelease(queue)
        wgpuDeviceRelease(device)
        return context
    }

    final class Retained {
        let instance: WGPUInstance
        let adapter: WGPUAdapter
        init(instance: WGPUInstance, adapter: WGPUAdapter) { self.instance = instance; self.adapter = adapter }
        deinit { wgpuAdapterRelease(adapter); wgpuInstanceRelease(instance) }
    }

    private final class Box<T> { var value: T?; var done = false }

    private static func requestAdapter(instance: WGPUInstance) -> WGPUAdapter? {
        let box = Box<WGPUAdapter>()
        var options = WGPURequestAdapterOptions()
        var info = WGPURequestAdapterCallbackInfo()
        info.mode = WGPUCallbackMode_AllowProcessEvents
        info.callback = { _, adapter, _, userdata, _ in
            let box = Unmanaged<Box<WGPUAdapter>>.fromOpaque(userdata!).takeUnretainedValue()
            box.value = adapter
            box.done = true
        }
        info.userdata1 = Unmanaged.passUnretained(box).toOpaque()
        _ = wgpuInstanceRequestAdapter(instance, &options, info)
        var spins = 0
        while !box.done, spins < 2048 { wgpuInstanceProcessEvents(instance); spins += 1 }
        return box.value
    }

    private static func requestDevice(instance: WGPUInstance, adapter: WGPUAdapter) -> WGPUDevice? {
        let box = Box<WGPUDevice>()
        var info = WGPURequestDeviceCallbackInfo()
        info.mode = WGPUCallbackMode_AllowProcessEvents
        info.callback = { _, device, _, userdata, _ in
            let box = Unmanaged<Box<WGPUDevice>>.fromOpaque(userdata!).takeUnretainedValue()
            box.value = device
            box.done = true
        }
        info.userdata1 = Unmanaged.passUnretained(box).toOpaque()
        var descriptor = WGPUDeviceDescriptor()
        descriptor.uncapturedErrorCallbackInfo.callback = { _, type, message, _, _ in
            let text = message.data.map { String(cString: $0) } ?? ""
            FileHandle.standardError.write(Data("[WGPU error \(type.rawValue)] \(text)\n".utf8))
        }
        _ = wgpuAdapterRequestDevice(adapter, &descriptor, info)
        var spins = 0
        while !box.done, spins < 2048 { wgpuInstanceProcessEvents(instance); spins += 1 }
        return box.value
    }
}
