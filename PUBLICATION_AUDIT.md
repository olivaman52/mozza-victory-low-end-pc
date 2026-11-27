# Publication audit — 2026-11-27

## Scope and outcome

Reviewed an exported current working-tree snapshot, including 305 non-audit files (all decodable UTF-8), plus five Git audit metadata files. The snapshot listed 55 recent commits, not the complete Git object database. This is a limited static privacy review, not a legal clearance, complete secret scan, build validation, or authorization to publish.

### Changes prepared

- Replaced absolute checkout paths in the current technical reports and all seven included historical reports with repository-relative paths. Benchmark numbers, source references, commit IDs, failures and technical findings are retained.
- Removed machine-specific defaults from the two PowerShell launch scripts: callers must supply the authorized local title path through `-Game`. The batch launcher now requires a caller-configured game directory rather than assuming a release-specific directory. Renderer code and performance settings are unchanged.
- Extended existing root `.gitignore` protections for local credentials, save data, caches and audit output. Ignore rules do not remove already tracked files or historical objects.
- Extended the existing review-package redaction function for checkout paths and common credential token formats; added JSON parsing checks before packaging redacted reports and benchmark evidence. This is a best-effort filter for packaged copies only, not a guarantee that live reports or all logs are safe to commit. Continue reviewing staged files and historical objects before publication.
- Preserved GPL license texts, upstream notices and public patch attribution.

### Findings requiring local review before publication

1. The supplied Git metadata contains a personal email address on 16 author entries and 16 committer entries for the local development identity (the same 16 commits). Other contributor addresses are also present. Decide whether the local identity should use a GitHub-provided noreply address and review the historical exposure. Changing `user.email` only affects future commits. Do not rewrite the original working repository without approval; keep other contributors' attribution intact.
2. Previous versions of the affected files may still contain private paths. The actual historical file contents were not exported; run the supplied read-only history scan locally. Review all reachable commits and every branch/tag intended for publication. Do not upload the private scan results without inspection.
3. The export omitted one tracked file: `cool_fox/crates/victory-formats/src/bcpack-tables.bin`. The upstream asset policy explicitly states that the repository license does not cover this table. Verify its independent redistribution permission before publishing any branch containing it, including historical versions. The export cannot establish its provenance or permissions. Do not remove or replace it in the local working copy as part of a privacy cleanup.
4. The top-level README contains historical statements about whether the vendored upstream is redistributed, and the current tree contains that vendored source. GPLv3 license files exist, but provenance and license compliance of all imported files and data are not independently established. Resolve the inconsistency, confirm the imported source and its permissions, and retain applicable notices and modification history before public distribution. No legal clearance is asserted.
5. No recognizable common GitHub/OpenAI/AWS credential token or private-key marker was found by the supplied snapshot's heuristic text scan. This is not proof of absence. The snapshot excludes ignored logs, caches, raw captures, archives and the binary table. Inspect the actual index and run a full history secret scanner locally before pushing. Raw evidence and local audit exports should remain private unless independently reviewed.

### Validation and limits

All supplied benchmark CSVs and report JSONs were retained without changes to their measurements or schema. Source files under the Rust crates were left byte-for-byte unchanged. The PowerShell changes were reviewed statically; PowerShell and the Windows runtime were not available in the audit environment, so they have not been executed or benchmarked. No files were committed, no Git history was rewritten, and nothing was uploaded to GitHub. Existing private saves, caches and build artifacts were not inspected or modified.

Keep the local development repository and rollback builds intact. A public release remains blocked pending the history/privacy and redistribution review above.
