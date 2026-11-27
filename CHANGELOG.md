# Changelog

## Local development

- Use one D3D12 Options19 query per device. Avoid oversized descriptor probes on drivers that report an explicit limit. Require real device-local GPU execution and exact results in the linked-record validation fixture.
- Preserve guest block boundaries with configurable CPU landing job sizes. Add opt-in refresh diagnostics and reconsider redundant range gathering while the submission already holds a write-watch result.
- Record benchmark PIDs, settings and lifecycle in atomic run receipts. Verify the review archive against a checkpoint manifest before replacing the previous archive.
- Port the Scarlett texture queue's partitioned sort while preserving eligibility and exact selection order. Keep the static-sampler cache workaround isolated because it increased warm-start compilation. [Scarlett source commit](https://github.com/Yaekai/victory-scarlett-3070/commit/b4ed67d89844be579f84d88b5b1a93030a8b2a5b)
- Deduplicate dirty buffer descriptors and periodic candidates with sparse per-range occupancy. Keep the periodic fallback.
- Reuse range storage during readback and add opt-in fence waits and landing attribution. Report indirect failures separately from the GPU work-budget counter. Add optional presentation intervals and observed resource extents.
- Correct the hardware budget-reset fixture to charge exact half-budget records under both policies.
- Add an opt-in placed-descriptor membership check to test Scarlett's span-lock optimization. Benchmark validation is pending.
- Keep guest GPU address directory slots owned by their view heap. Distinguish full guest byte addresses in list staging and readback keys. Verify the producer and consumer with a hardware round trip.
- Reuse and index CPU readback exclusion spans while preserving the original lock and fence policy.
- Screen clipped guest descriptor reads behind a flag. Record accepted DXGI intervals, host compute dispatches and Windows CPU/GPU activity during targeted benchmarks.

- Make the card buffer cap and texture mip drop selectable through the Windows launcher while preserving upstream defaults.
- Preserve the bounded host command-list pool with healthy commit headroom, even under physical RAM pressure. Release idle lists and preludes on low commit or a command-list close allocation failure.
- Separate the indirect-light clamp from the ambient-strength setting for visual diagnosis. Default lighting is preserved.
- Complete a panicking pipeline queue entry with an explicit failure and keep the worker available, following [fxceless's queue fix](https://github.com/fxceless/victory-fork/commit/46da5ee).
- Decode BC7 channel rotation only in the modes that encode it, following [VIctory's decoder fix](https://github.com/Marvisak/VIctory/pull/3111).
- Add opt-in presentation interval percentiles, structured counters and JSON export.
- Match legacy RDNA 2 fused multiply-add and input flush behavior, validated against a CPU reference. [Original shader fix](https://github.com/fxceless/victory-fork/commit/f6a09d3)
- Exercise both indirect command budget policies in the WARP fixture.
