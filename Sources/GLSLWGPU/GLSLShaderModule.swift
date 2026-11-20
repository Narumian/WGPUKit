import WGPUKit

/// A shader module made from GLSL (wgpu's naga front end), checked inside an error scope: wgpu hands out an object even for source
/// it rejects and reports the problem as a validation error, so a failure comes back as nil or as a message.
/// Format players (ISF, laser materials) generate GLSL; this is where it first meets the device.
public enum GLSLShaderModule {
    public enum Stage: Sendable { case vertex, fragment }

    /// nil when the source compiles; otherwise the validation message.
    public static func check(_ source: String, stage: Stage, context: WGPUSharedContext) -> String? {
        let (module, message) = build(source, stage: stage, context: context)
        if let module { wgpuShaderModuleRelease(module) }
        if message == nil && module == nil { return "no module" }
        return message
    }

    /// The module (entry point `main`), or nil when the source is rejected. The caller releases it.
    public static func makeModule(_ source: String, stage: Stage, context: WGPUSharedContext) -> WGPUShaderModule? {
        let (module, message) = build(source, stage: stage, context: context)
        if message != nil, let module { wgpuShaderModuleRelease(module); return nil }
        return module
    }

    private static func build(_ source: String, stage: Stage, context: WGPUSharedContext) -> (WGPUShaderModule?, String?) {
        let device = context.device
        wgpuDevicePushErrorScope(device, WGPUErrorFilter_Validation)
        var bytes = Array(source.utf8CString)
        bytes.removeLast()
        let module: WGPUShaderModule? = bytes.withUnsafeBufferPointer { buffer in
            var glsl = WGPUShaderSourceGLSL()
            glsl.chain.sType = WGPUSType(rawValue: WGPUSType_ShaderSourceGLSL.rawValue)
            glsl.stage = stage == .vertex ? WGPUShaderStage_Vertex : WGPUShaderStage_Fragment
            glsl.code = WGPUStringView(data: buffer.baseAddress, length: buffer.count)
            glsl.defineCount = 0
            glsl.defines = nil
            return withChained(&glsl) { chain in
                var descriptor = WGPUShaderModuleDescriptor()
                descriptor.nextInChain = chain
                return wgpuDeviceCreateShaderModule(device, &descriptor)
            }
        }
        return (module, popValidationScope(device))
    }

    private final class ScopeBox { var message: String?; var done = false }

    /// Closes an error scope opened with `wgpuDevicePushErrorScope(device, Validation)`; the message it caught, or nil for none.
    public static func popValidationScope(_ device: WGPUDevice) -> String? {
        let box = ScopeBox()
        var info = WGPUPopErrorScopeCallbackInfo()
        info.mode = WGPUCallbackMode_AllowSpontaneous
        info.callback = { _, type, message, userdata, _ in
            let box = Unmanaged<ScopeBox>.fromOpaque(userdata!).takeUnretainedValue()
            if type != WGPUErrorType_NoError {
                if let data = message.data, message.length > 0 {
                    box.message = String(decoding: UnsafeRawBufferPointer(start: data, count: message.length), as: UTF8.self)
                } else { box.message = "validation error" }
            }
            box.done = true
        }
        info.userdata1 = Unmanaged.passUnretained(box).toOpaque()
        _ = wgpuDevicePopErrorScope(device, info)
        var spins = 0
        while !box.done && spins < 10_000 { _ = wgpuDevicePoll(device, 0, nil); spins += 1 }
        return box.message
    }
}
