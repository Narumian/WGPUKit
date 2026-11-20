import WGPUKit

/// The pipeline every GLSL full-target pass uses: one vertex buffer of vec4 positions (a triangle strip of four, in the target's own
/// units because the GLSL vertex shader maps them itself), no culling, no blending, one color target.
public enum GLSLQuadPipeline {
    public struct Failure: Error, CustomStringConvertible, Sendable {
        public let description: String
        init(_ description: String) { self.description = description }
    }

    /// Stride of the vertex buffer: one vec4 per corner.
    public static let vertexStride = 16

    /// Made inside an error scope: wgpu hands out objects for descriptors it rejects.
    public static func make(device: WGPUDevice, layout: WGPUPipelineLayout, vertex: WGPUShaderModule, fragment: WGPUShaderModule,
                            format: WGPUTextureFormat) throws -> WGPURenderPipeline {
        wgpuDevicePushErrorScope(device, WGPUErrorFilter_Validation)
        let made: WGPURenderPipeline? = withWGPUString("main") { entry in
            var attribute = WGPUVertexAttribute()
            attribute.format = WGPUVertexFormat_Float32x4
            attribute.offset = 0
            attribute.shaderLocation = 0
            return withUnsafePointer(to: &attribute) { attributePointer in
                var vertexLayout = WGPUVertexBufferLayout()
                vertexLayout.arrayStride = UInt64(vertexStride)
                vertexLayout.stepMode = WGPUVertexStepMode_Vertex
                vertexLayout.attributeCount = 1
                vertexLayout.attributes = attributePointer
                return withUnsafePointer(to: &vertexLayout) { vertexLayoutPointer in
                    var target = WGPUColorTargetState()
                    target.format = format
                    target.writeMask = WGPUColorWriteMask_All
                    return withUnsafePointer(to: &target) { targetPointer in
                        var fragmentState = WGPUFragmentState()
                        fragmentState.module = fragment
                        fragmentState.entryPoint = entry
                        fragmentState.targetCount = 1
                        fragmentState.targets = targetPointer
                        return withUnsafePointer(to: &fragmentState) { fragmentPointer in
                            var descriptor = WGPURenderPipelineDescriptor()
                            descriptor.layout = layout
                            descriptor.vertex.module = vertex
                            descriptor.vertex.entryPoint = entry
                            descriptor.vertex.bufferCount = 1
                            descriptor.vertex.buffers = vertexLayoutPointer
                            descriptor.primitive.topology = WGPUPrimitiveTopology_TriangleStrip
                            descriptor.primitive.frontFace = WGPUFrontFace_CCW
                            descriptor.primitive.cullMode = WGPUCullMode_None
                            descriptor.multisample.count = 1
                            descriptor.multisample.mask = UInt32.max
                            descriptor.fragment = fragmentPointer
                            return wgpuDeviceCreateRenderPipeline(device, &descriptor)
                        }
                    }
                }
            }
        }
        if let message = GLSLShaderModule.popValidationScope(device) {
            if let made { wgpuRenderPipelineRelease(made) }
            throw Failure("pipeline: \(message)")
        }
        guard let made else { throw Failure("pipeline") }
        return made
    }

    /// Four corners of a `width` x `height` target, in pixels, as the strip the pipeline draws.
    public static func cornerPositions(width: Int, height: Int) -> [Float] {
        let w = Float(width), h = Float(height)
        return [0, 0, 0, 1,  w, 0, 0, 1,  0, h, 0, 1,  w, h, 0, 1]
    }
}
