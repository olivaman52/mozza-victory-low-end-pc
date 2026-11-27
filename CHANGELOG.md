# Changelog

## Local development

- Port the Scarlett texture queue's partitioned sort while preserving eligibility and exact selection order. Keep the static-sampler cache workaround isolated because it increased warm-start compilation. [Scarlett source commit](https://github.com/Yaekai/victory-scarlett-3070/commit/b4ed67d89844be579f84d88b5b1a93030a8b2a5b)

- Make the card buffer cap and texture mip drop selectable through the Windows launcher while preserving upstream defaults.
- Preserve the bounded host command-list pool with healthy commit headroom, even under physical RAM pressure. Release idle lists and preludes on low commit or a command-list close allocation failure.
- Separate the indirect-light clamp from the ambient-strength setting for visual diagnosis. Default lighting is preserved.
- Complete a panicking pipeline queue entry with an explicit failure and keep the worker available, following [fxceless's queue fix](https://github.com/fxceless/victory-fork/commit/46da5ee).
- Decode BC7 channel rotation only in the modes that encode it, following [VIctory's decoder fix](https://github.com/Marvisak/VIctory/pull/3111).
- Add opt-in presentation interval percentiles, structured counters and JSON export.
- Match legacy RDNA 2 fused multiply-add and input flush behavior, validated against a CPU reference. [Original shader fix](https://github.com/fxceless/victory-fork/commit/f6a09d3)
- Exercise both indirect command budget policies in the WARP fixture.
