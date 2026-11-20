import WGPUKit

/// The pointer plumbing around bind group layouts, pipeline layouts and bind groups.
public enum GPUBindings {
    public static func makeBindGroupLayout(device: WGPUDevice, entries: [WGPUBindGroupLayoutEntry]) -> WGPUBindGroupLayout? {
        entries.withUnsafeBufferPointer { pointer in
            var descriptor = WGPUBindGroupLayoutDescriptor()
            descriptor.entryCount = pointer.count
            descriptor.entries = pointer.baseAddress
            return wgpuDeviceCreateBindGroupLayout(device, &descriptor)
        }
    }

    public static func makePipelineLayout(device: WGPUDevice, layouts: [WGPUBindGroupLayout]) -> WGPUPipelineLayout? {
        let optional: [WGPUBindGroupLayout?] = layouts
        return optional.withUnsafeBufferPointer { pointer in
            var descriptor = WGPUPipelineLayoutDescriptor()
            descriptor.bindGroupLayoutCount = pointer.count
            descriptor.bindGroupLayouts = pointer.baseAddress
            return wgpuDeviceCreatePipelineLayout(device, &descriptor)
        }
    }

    public static func makeBindGroup(device: WGPUDevice, layout: WGPUBindGroupLayout, entries: [WGPUBindGroupEntry]) -> WGPUBindGroup? {
        entries.withUnsafeBufferPointer { pointer in
            var descriptor = WGPUBindGroupDescriptor()
            descriptor.layout = layout
            descriptor.entryCount = pointer.count
            descriptor.entries = pointer.baseAddress
            return wgpuDeviceCreateBindGroup(device, &descriptor)
        }
    }
}
