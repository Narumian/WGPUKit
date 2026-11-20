import WGPUKit

/// The bytes of a std140 uniform block, written at the offsets a shader's layout gives (for GLSL generated from a program these come
/// with the program). Values past the end of the block are ignored. Blocks are at least 16 bytes: wgpu does not accept less.
public struct UniformBlock {
    public private(set) var bytes: [UInt8]

    public init(size: Int) { bytes = [UInt8](repeating: 0, count: max(16, size)) }

    public var count: Int { bytes.count }

    public mutating func setFloat(_ value: Float, at offset: Int) {
        guard offset >= 0, offset + 4 <= bytes.count else { return }
        withUnsafeBytes(of: value) { for i in 0..<4 { bytes[offset + i] = $0[i] } }
    }

    public mutating func setInt32(_ value: Int32, at offset: Int) {
        guard offset >= 0, offset + 4 <= bytes.count else { return }
        withUnsafeBytes(of: value) { for i in 0..<4 { bytes[offset + i] = $0[i] } }
    }

    /// Up to four consecutive floats from `offset` (a float, vec2, vec3 or vec4 member).
    public mutating func setFloats(_ values: [Float], at offset: Int) {
        for (index, value) in values.prefix(4).enumerated() { setFloat(value, at: offset + index * 4) }
    }

    /// Copies the block to the start of `buffer` through the queue.
    public func write(to buffer: WGPUBuffer, queue: WGPUQueue) {
        bytes.withUnsafeBytes { wgpuQueueWriteBuffer(queue, buffer, 0, $0.baseAddress, $0.count) }
    }
}
