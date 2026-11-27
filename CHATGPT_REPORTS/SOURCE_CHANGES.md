# Victory source changes for review

## Selective Scarlett integration

`95aa317` adapts the queue selection from `aae3811` and ports the common harness. `TextureQueue::due` partitions the due retry and fresh lists before sorting just the selected entries. The differential fixture verifies exact selection and ordering under varied limits. The port passed the opening checkpoint with the original static-sampler cache policy. Texture processing changed from 18.35 to 15.27 ms in sampled runs. Overall FPS was 6.82 versus 6.89, so gameplay benefit is unproven. The default cache-bypass run was still compiling at close and rebuilt hundreds of pipelines that stayed cached with queue-only.

## Phase 2 recovery

The current changes repair indirect rejection propagation and sparse descriptor iteration. `indirect::validate_layout` and `bound` return the observed failure without loosening layout or address checks. `draw::State::lighting_view` checks the handle belongs to the active heap and to a descriptor boundary before reading. `Host::relay_card_back` records opt-in sampled event-wait time and reuses a range vector within a landing job. The first compiler check found a borrowed iterator reference, which now moves into the iterator closure. Full release validation is in progress.

## Phase 1 and Scarlett ports

| Change and provenance | Files and behavior | Verification, impact and rollback |
|---|---|---|
| `7805667` commit-aware pool pressure | `victory-gpu/src/{host,list,residency}.rs`. Keep idle host list and allocator reuse while Windows commit headroom is healthy. Retain emergency clearing on allocation failures. | Matched cap and mip settings went from 4.34 to 6.45 FPS. List allocations were much lower. Use the original release executable to isolate the change. |
| `b116467` BC7 and worker recovery | `victory-formats/src/bcpack.rs` corrects BC7 channel rotation. `victory-gpu/src/pipeline/make.rs` converts worker panic to failure and preserves recovery. `ambient.rs` adds a diagnostic clamp option. | Focused fixtures passed. Brightness clamp experiment left blocky edges visible. Restore the earlier binary to isolate these changes and leave the override disabled for matched runs. |
| `99b1b47` indirect policy tests | `victory-gpu/src/indirect.rs` verifies both list-budget modes in WARP, with the opt-in setting made explicit. | Nine indirect tests and three queue/fence tests passed. Runtime drop attribution remains pending. |
| `2789f51` legacy arithmetic | `victory-shader/src/emit/lower.rs` compiles the guest legacy multiply-add as a fused operation with the required zero handling. `emit/valu_tests.rs` adds an arithmetic reference fixture. | Hardware CPU/reference comparison passed on RTX 3060 Ti. |
| `714cda3`, from Scarlett | `victory-gpu/src/pipeline/{host,library}.rs`. A scoped policy bypasses persistent pipeline library reuse for static-sampler pipelines and restores the policy for nested work. | Six focused cache tests passed. Warm application benchmark and cross-process artifact reproduction remain pending. Run preserved `8999b80` for direct comparison instead of altering existing game data or cache. |
| `aae3811`, adapted from Scarlett `b4ed67d` | `victory-gpu/src/descriptor/host.rs`, texture queue selection. Partition candidates and sort the subset selected by the original earliest/newest and retry ordering. | Three focused tests passed. Identical selection against the reference sort across all tested limits. CPU fixture improved from 5.10 to 1.45 ms at 256 requests, with gameplay impact pending. |
| `3078989` benchmark runner | `scripts/compare-scarlett.ps1` and `scripts/summarize-scarlett.ps1`. Match one workload and settings, save process exit and sampled windows, and preserve per-fork cache separation. | Runtime logs and benchmark exports retained locally. A short cold sample estimates compilation and startup behavior. It cannot characterize steady performance. |

Paths under `victory-gpu/src`, `victory-shader/src`, and `victory-formats/src` belong to `cool_fox/crates`. The integration source remains on `codex/scarlett-integration`, based on `8999b80`. See [SCARLETT_REPORT.md](SCARLETT_REPORT.md) for the excluded Scarlett launcher behaviors and comparison methodology.

## Unfinished Phase 2 source

The pre-Scarlett snapshot is preserved as `cool_fox/target/benchmarks/phase2-pre-scarlett.patch` and `phase2-pre-scarlett-untracked`. The working tree adds descriptor sweep metrics and deduplication in `draw.rs` and `descriptor/host.rs`, presentation timing in `host.rs`, extra extent diagnostics in `ambient.rs`, `draw.rs`, and `host/spans.rs`, provenance and temporary buffer work in `land.rs`, `land/readback_trace.rs`, `shadow.rs` and `texback.rs`, and indirect reasons in `list.rs`, `list/indirect_drops.rs`, `draw.rs`, `pipeline.rs`, and `pipeline/make.rs`.

Apply and validate these changes separately from the Scarlett benchmark. The archive includes the tracked compact diff. The two untracked modules stay in the local recovery copy until the recovered patch is reviewed and built.
