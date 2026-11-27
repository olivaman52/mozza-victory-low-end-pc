# Frame generation status

Frame generation is deferred. The best cited controlled opening-scene sample measured 6.93 accepted DXGI presents per second. This counter does not independently measure displayed or rendered FPS. The tested build has zero generated frames.

NVIDIA's official matrix does not list RTX 30 Series for DLSS Frame Generation or Multi Frame Generation. AMD lists RTX 30 Series as recommended hardware for FSR 3.1 Frame Generation and recommends an input near 60 FPS. Its developer guidance strongly discourages input below 30 FPS. [NVIDIA DLSS hardware matrix](https://www.nvidia.com/en-us/geforce/technologies/dlss/) · [AMD FSR 3.1 release notes](https://gpuopen.com/learn/amd_fsr_3_1_release/) · [AMD frame-generation integration](https://gpuopen.com/amd-fsr-framegeneration/)

Revisit FSR frame generation once the real renderer consistently reaches at least 30 FPS with stable frame times. Before binding any supported SDK, identify the pre-HUD output and tie it to depth, motion, camera and fences using a single guest frame serial. Verify UI separation and reset handling across cuts, loading, resizes and suspend. Measure rendered, generated and presented FPS separately, with latency and VRAM overhead.
