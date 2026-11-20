# WGPUKit

The GPU foundation shared by SwiftXUI and the shader/format packages built on wgpu-native. No UI, no laser, no file formats.

| Product | Role |
|---------|------|
| `CWGPU` | wgpu-native C API (binary target, `Vendor/CWGPU.xcframework`) |
| `WGPUKit` | `WGPUSharedContext` (device + queue handle, the window's published context), `withChained`, `withWGPUString`; re-exports `CWGPU` |
| `GLSLWGPU` | GLSL on WGPU: `GLSLShaderModule` (naga front end, error-scoped), `GLSLQuadPipeline`, `UniformBlock` (std140 bytes), `GPUTexture2D`, `GPUBindings`, `GPUReadback` (async + blocking) |

## Setup

```bash
bash Scripts/fetch-wgpu.sh
```

Creates `Vendor/CWGPU.xcframework` (iOS device, iOS simulator, macOS arm64) from the pinned wgpu-native release. Not in git.
Follow wgpu-native's license if you redistribute the xcframework.

## License

Apache License 2.0 (see `LICENSE`). wgpu-native, fetched by `Scripts/fetch-wgpu.sh`, has its own license (MIT / Apache 2.0); follow it if you redistribute the xcframework.
