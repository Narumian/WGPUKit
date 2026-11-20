@_exported import CWGPU

/// Passes a Swift String as a `WGPUStringView` that is valid while the closure runs.
/// wgpu-native copies the contents during create calls, so this lifetime is enough.
@inline(__always)
public func withWGPUString<R>(_ string: String, _ body: (WGPUStringView) -> R) -> R {
    var s = string
    return s.withUTF8 { buf in
        body(WGPUStringView(data: buf.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) },
                            length: buf.count))
    }
}
