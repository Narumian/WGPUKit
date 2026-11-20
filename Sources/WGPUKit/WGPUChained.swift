@_exported import CWGPU

/// Plugs a value-type chained extension struct (its first field is `WGPUChainedStruct chain`) into a parent descriptor's
/// `nextInChain` and runs the closure.
@inline(__always)
public func withChained<C, R>(_ chained: inout C, _ body: (UnsafeMutablePointer<WGPUChainedStruct>) -> R) -> R {
    withUnsafeMutablePointer(to: &chained) { ptr in
        body(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: WGPUChainedStruct.self))
    }
}
