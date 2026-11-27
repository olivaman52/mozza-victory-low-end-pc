# Upscaling status

Keep the existing title upscaler and presentation path for the current benchmarks. The swap chain reports 1920×1080. Existing logs show named FSR4 ACO fallback passes and lighting buffers of 1280×720, 640×360 and 80×46. These are pass observations. The main color target, active viewport and upscaler input and output sizes still need to be identified.

The recovered opt-in `VICTORY_RENDER_DIMENSIONS` diagnostic records host base-level scene-depth and lighting resource extents for known compute passes. It stays off in throughput runs. It does not derive upscaling dimensions from a lighting buffer.

NVIDIA lists DLSS Super Resolution for RTX 30 Series. Streamline is the supported integration candidate. AMD FSR 3.1 upscale-only is another candidate. Both remain unimplemented. Establish the upstream stage and measure the critical path before integrating a replacement. [NVIDIA DLSS hardware matrix](https://www.nvidia.com/en-us/geforce/technologies/dlss/) · [AMD FSR 3.1](https://gpuopen.com/fidelityfx-super-resolution-3/)

An implementation needs matching pre-HUD color, motion vectors, depth, jitter, exposure, history-reset signals, and resource and fence ownership. After proving those inputs, compare native, Quality, Balanced and Performance modes using actual render sizes, rendered frame times, screenshots and memory.
