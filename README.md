# Victory — Low-End PC

**An experimental, AI-assisted performance and graphics compatibility fork of Victory, focused on memory-constrained Windows PCs and mid-range GPUs.**

Based on [WASDeKeys/victory-low-end-pc](https://github.com/WASDeKeys/victory-low-end-pc), with its inherited cool_fox source and selected, individually evaluated improvements from other Victory forks. Development uses OpenAI Codex for implementation, profiling and testing, with technical reviews of the resulting evidence.

The aim is to improve actual frame throughput, memory management, rendering correctness and stability — not to inflate FPS by dropping required rendering operations or counting generated frames.

> **Development preview — source and research only.** This is not a complete or ready-to-play release. The public tree deliberately excludes `bcpack-tables.bin` pending confirmation of its independent redistribution rights. Consequently, it cannot currently be built as-is. Some source changes are experimental and have not passed full runtime validation. See [publication and build status](#publication-and-build-status).

[Performance](#windows-performance) · [Changes](#development-progress) · [Known limitations](#known-limitations) · [Reports](#open-development-reports) · [Roadmap](#roadmap) · [Credits](#credits)

## Windows performance

### Test hardware

| Component | Test system |
|---|---|
| CPU | Intel Core i7-12700F (8 P-cores, 4 E-cores, 20 threads) |
| GPU | NVIDIA GeForce RTX 3060 Ti, 8 GiB VRAM |
| RAM | 32 GiB |
| Platform | Windows, Direct3D 12 |
| Console profile | Series S |
| Presentation resolution | 1920 × 1080; internal scene resolution not verified |
| Frame generation | None |

### Development benchmarks

The following measurements are from local Windows development builds, not from a build of this incomplete public snapshot.

| Configuration | Reported FPS | Mean frame time |
|---|---:|---:|
| Original WASDeKeys stock, 512 MiB buffer cap, mip drop 3 | 2.42 | 413 ms |
| Same stock build, 1,024 MiB cap, mip drop 3 | 4.34 | 230.4 ms |
| Commit-aware command-list recycling, 1,024 MiB, mip drop 3 | 6.45 | 155.1 ms |
| Phase 1 final release, 1,024 MiB, mip drop 1 | 6.79 | 147.3 ms |
| Preserved Phase 1 warm checkpoint | 6.89 | 145.2 ms |
| Phase 2 clean baseline | 6.82 | — |
| Phase 2 descriptor-clipping control | 6.93 | — |
| Phase 2 coverage-index retry, index off | 6.83 | 146.50 ms |

The Phase 1 final release measured roughly 2.8× the reported throughput of the initial stock run on this machine. This is an observed end-to-end difference across configuration and code changes, not an isolated or universally reproducible speedup. In particular, texture settings, scene timing and background workload differ between some runs.

The best cited controlled opening-scene comparison measured **6.93 accepted presentations per second**. A separate long six-worker run recorded individual one-minute windows up to **7.71 accepted presentations per second**; those later windows are historical observations, not a matched benchmark or proof of a stable 7.71 FPS renderer.

Earlier measurements use the inherited frame statistics; newer measurements use raw accepted DXGI presentation intervals. Neither independently verifies displayed or rendered frame counts. No frame generation was used. Rendering is incomplete, so these results must not be interpreted as fully correct gameplay performance, broad compatibility or performance in later environments.

Full evidence: [Performance results](PERFORMANCE_RESULTS.md) · [Benchmark history CSV](CHATGPT_REPORTS/BENCHMARK_HISTORY.csv) · [Recommended configuration](RECOMMENDED_CONFIG.md).

### Shader and pipeline warm-up

Historical one-minute windows from the approximately seven-hour six-worker run:

| Elapsed window | Accepted-present FPS | p95 frame time | Peak logged pending pipelines |
|---|---:|---:|---:|
| 5–6 min | 7.36 | 165.76 ms | 3 |
| 10–11 min | 7.71 | 150.07 ms | 0 |
| 15–16 min | 7.58 | 150.32 ms | 0 |
| 20–21 min | 7.71 | 153.58 ms | 0 |
| 30–31 min | 7.64 | 155.82 ms | 0 |

These observations suggest that an early benchmark can understate later throughput. They do not establish that shader compilation caused the change, because scene content and system activity were not controlled throughout. The long run survived until a requested shutdown; it does not establish complete rendering correctness or general stability.

A separate controlled four-worker warm-cache investigation had interim windows of 6.89, 7.11 and 6.89 accepted presents per second at minutes five, ten and fifteen. The final measurement and warmed restart were still pending in the supplied report snapshot. Preserve compatible caches and distinguish shader resolution, active translation and pending pipeline creation when comparing results.

See the [shader warm-up report](CHATGPT_REPORTS/SHADER_WARMUP_REPORT.md) for methodology, measurements and outstanding validation.

## Development progress

### Implemented and investigated

- Commit-aware command-list recycling: retain reusable lists with healthy commit headroom and trim on low commit or allocation failure.
- Configurable card-buffer budget and texture mip selection, with lower-memory fallback profiles.
- Pipeline-worker panic recovery and targeted shader arithmetic and BC7 channel-rotation corrections.
- Incremental descriptor candidate deduplication, sparse iteration and readback scratch/exclusion reuse.
- Explicit indirect-rejection diagnostics, raw presentation intervals, latency percentiles, render-resource extent logging and benchmark exports.
- Selective Scarlett texture-queue ordering optimization, validated against the original selection behavior.
- BVH address bookkeeping corrections, heap-owned descriptor directory reservations and hardware capability-aware descriptor heap probing.

Selected tests have passed, including focused descriptor and coverage tests, CPU reference shader arithmetic, WARP indirect and queue fixtures, and an RTX 3060 Ti producer/consumer pointer fixture that preserved exact output bytes and adjacent sentinels. The latter does not establish full in-title BVH correctness. GPU-based validation was requested in one fixture run, but activation was not independently confirmed.

### Experimental results that did not justify a default change

| Experiment | Control → candidate | Decision |
|---|---|---|
| Guest descriptor read clipping | 6.93 → 6.88 FPS; reads 11.51 → 6.02 MiB/frame | Keep off |
| Four → six landing workers | 6.93 → 6.87 FPS; landing 39.29 → 34.37 ms | Retain four |
| 256 → 512 KiB landing jobs | 6.62 → 6.62 FPS | Retain 256 KiB |
| Indexed coverage lookup | 6.83 → 6.73 accepted FPS | Keep off |
| Scarlett queue-only port | 6.89 → 6.82 FPS in historical warm windows | No proven throughput gain; ordering-preserving port retained |
| Scarlett static-sampler cache workaround | Increased warm-start pipeline compilation | Keep isolated |

These are screening comparisons, not necessarily statistically significant differences. The project retains negative results to avoid repeating ineffective investigations.

See [CHANGELOG.md](CHANGELOG.md), [SOURCE_CHANGES.md](CHATGPT_REPORTS/SOURCE_CHANGES.md) and [SCARLETT_REPORT.md](SCARLETT_REPORT.md).

## Known limitations

| Area | Current status |
|---|---|
| Lighting and shadows | Dark interior lighting remains unresolved. The inherited ambient-light stand-in is approximate. |
| Ray tracing / BVH | Offline translation and synthetic hardware fixtures have passed for selected components. The full builder remains gated pending end-to-end validation. |
| Missing operations | Hundreds of missing pipeline draws and indirect rejections were observed per frame in earlier gameplay samples. Required graphics work remains incomplete. |
| Wave64 | Some divergent reductions, lane masks and cross-wave operations still lack correct Wave32 lowering. |
| Descriptor capacity | Guest requests can exceed the tested host's one-million shader-visible view slots; general virtualization remains incomplete. |
| Buffer alignment | Some unaligned buffer views are unsupported; exact-byte behavior needs further validation. |
| Textures and geometry | Character hair and geometry can render correctly in some inspected frames, but intermittent artifacts and texture quality limitations remain. |
| Memory pressure | Higher buffer caps and sharper textures can increase VRAM usage and system commit pressure. |
| Resolution | The 1080p presentation size is verified, not the primary internal scene resolution. |
| DLSS / FSR | Alternative upscaler integration is not implemented. |
| Frame generation | Deferred; no generated frames in reported benchmarks. |
| Stability | Limited opening-scene testing; later gameplay, additional GPUs, and long-term correctness remain unverified. |

See [COMPATIBILITY_STATUS.md](COMPATIBILITY_STATUS.md) for more detailed evidence.

## Open development reports

A central goal of this fork is to document AI-assisted engineering openly, including the experiments that did not work. Reports describe the local development state at the time they were recorded; some evidence paths refer to private local artifacts that are not distributed with this repository.

| Document | Contents |
|---|---|
| [Latest report](CHATGPT_REPORTS/LATEST_REPORT.md) | Latest recorded checkpoint, profiling findings and pending work |
| [Source changes](CHATGPT_REPORTS/SOURCE_CHANGES.md) | Implementation details, source references and validation |
| [Benchmark history](CHATGPT_REPORTS/BENCHMARK_HISTORY.csv) | Historical measurements and experimental configurations |
| [Shader warm-up](CHATGPT_REPORTS/SHADER_WARMUP_REPORT.md) | Cache and extended runtime investigations |
| [Report history](CHATGPT_REPORTS/HISTORY/) | Earlier development reports |
| [Performance results](PERFORMANCE_RESULTS.md) | Detailed benchmark comparisons |
| [Recommended configuration](RECOMMENDED_CONFIG.md) | Locally tested profiles and experimental options |
| [Compatibility status](COMPATIBILITY_STATUS.md) | Graphics correctness and unsupported functionality |
| [Scarlett comparison](SCARLETT_REPORT.md) | Cross-fork comparison and selective integration |
| [Fix plan](VICTORY_FIX_PLAN.md) | Outstanding engineering tasks |
| [Upscaling status](UPSCALING_STATUS.md) | Render-resolution investigation and future options |
| [Frame generation status](FRAME_GENERATION_STATUS.md) | Deferred frame-generation research |
| [Handoff](HANDOFF.md) | Historical continuation notes |
| [Publication audit](PUBLICATION_AUDIT.md) | Privacy review scope and remaining redistribution concerns |

Git history was sanitized in a separate publication clone. Commit hashes recorded in reports may refer to the original development history rather than the rewritten public commits. Private runtime logs, caches, saved data and binaries are not part of the published review material. The public reports preserve technical findings, not necessarily every supporting local artifact.

## Roadmap

The next priority is identifying what actually delays presentation, rather than optimizing subsystems solely because their counters are large.

- [ ] Complete the controlled warm-cache run and warmed restart.
- [ ] Profile the CPU/GPU critical path and expensive compatibility-layer GPU operations.
- [ ] Investigate redundant resource lookups and texture-queue contention without dropping UAV tracking, alias handling or resource transitions.
- [ ] Improve descriptor processing, memory coherency and CPU/GPU overlap based on measured evidence.
- [ ] Validate full BVH stages, fix lighting and reduce required operation failures.
- [ ] Improve Wave64 translation and descriptor virtualization.
- [ ] Identify actual internal rendering and native upscaler dimensions.
- [ ] Investigate supported alternative upscaling after the rendering path is validated.
- [ ] Revisit compatible frame generation only when base performance and correctness justify it.
- [ ] Establish redistribution clearance and a buildable public source tree.

Performance milestones of 10, 15, 20 and eventually 30 real rendered FPS are research goals, not promised results. Graphics correctness, reproducibility and stability remain essential.

## Publication and build status

The public repository is a source and research snapshot, not a supported binary distribution. The BCPack table at `cool_fox/crates/victory-formats/src/bcpack-tables.bin` has been omitted from the public history pending confirmation of its redistribution rights. The inherited [asset policy](cool_fox/docs/asset-policy.md) explicitly states that this table is outside the repository's license. The existing code depends on it, so a normal build of this public checkout is currently incomplete.

The inherited Windows and Linux build/launch scripts are retained as development material; earlier successful local builds do not demonstrate that this public snapshot can compile. There is no supported public installation or gameplay procedure at this stage. Use only authorized materials for development and testing.

A limited privacy review and history pattern scan were performed. They do not constitute exhaustive security, provenance or legal certification. Redistribution permissions for imported materials must be independently confirmed before publication or further distribution. Preserve applicable licenses, notices and attribution. Do not submit proprietary title assets, extracted code or data, private credentials, unauthorized captures or personal logs.

## Historical upstream benchmarks (Linux)

The original WASDeKeys README described work against [codec-d/cool_fox](https://github.com/codec-d/cool_fox) at `f4b48ad766ddbec1a1867022cd42f7645b0dd55e`. It reported the following Linux/Wine results on an Intel Core i7-13700KF system with 62 GB RAM, using the Series S profile and the first playable scene:

| Upstream configuration | Frame time | Reported FPS | Runs |
|---|---:|---:|---:|
| Unmodified cool_fox, original launcher settings | 360–410 ms | 2.4–2.8 | 1 |
| Patches 0001–0002, mip drop 2 | 271–291 ms | 3.4–3.7 | 5 |
| 1,024 MiB buffers, 256 MiB windows, mip drop 1 | 98–112 ms | 9–10 | 5 |
| 1,024 MiB buffers, 768 MiB windows, mip drop 3 | 100–106 ms | 9.4–9.9 | 5 |

These are **upstream measurements**, not results from this fork's RTX 3060 Ti Windows testing. The upstream report also described missing head geometry, deformed hair, approximate lighting and limited scene coverage. See [RESULTS.md](RESULTS.md) for the inherited methodology and measurements. Historical upstream setup instructions and patch descriptions remain in the earlier README revisions and patch files.

## Contributing

Technical feedback, reproducible bug reports, synthetic correctness fixtures, benchmark analyses and carefully scoped performance patches are welcome. For useful comparisons, report hardware, OS, source revision, executable identity, cache state, scene/workload, configuration, sample duration, frame-time percentiles and observed graphics defects. Keep profiling captures separate from throughput tests, and distinguish accepted presentations from independently measured rendered or displayed frames.

Do not include proprietary content or personal information in issue reports or patches. Preserve original contributor attribution and prefer small, reversible changes with documented correctness tests.

## Credits

- [WASDeKeys/victory-low-end-pc](https://github.com/WASDeKeys/victory-low-end-pc) — primary development base and inherited optimization work.
- [VIctory](https://github.com/Marvisak/VIctory) — Marvisak and contributors, original compatibility layer.
- [codec-d/cool_fox](https://github.com/codec-d/cool_fox) — codec_d, inherited fork and launcher settings.
- [avatarmanz/VIctory-7900XTX](https://github.com/avatarmanz/VIctory-7900XTX) — ancestor fork.
- [fxceless/victory-fork](https://github.com/fxceless/victory-fork) — upstream development and selected fixes.
- [Yaekai/victory-scarlett-3070](https://github.com/Yaekai/victory-scarlett-3070) — selective optimization comparison and ported queue improvements.
- Impre-visible — inherited shader-loop patch, diagnostics patches and texture mip-drop port.
- antikohza — original texture mip-drop idea and implementation.
- Claude Code — AI assistance credited by the inherited project for its original patches.
- OpenAI Codex and ChatGPT — implementation and technical review assistance for this fork's subsequent development.

This is an independent project, not affiliated with or endorsed by the title developer, publisher or upstream Victory maintainers.

## License

The inherited project identifies its covered source and patches as GPL-3.0-or-later. See [LICENSE](LICENSE), the [vendored license](cool_fox/LICENSE) and individual source notices. Third-party material may be subject to separate terms; the repository license does not establish rights to excluded proprietary data. The BCPack table is not distributed in this public snapshot.
