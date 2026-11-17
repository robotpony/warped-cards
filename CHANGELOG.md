# Changelog

Spec changes, newest first: what a port has to change to stay in step (PORTING.md › Versions). The spec version is `specVersion` in [spec.json](cribbage/minigames/spec.json). Each platform's builds have their own changelog, such as [apps/apple/CHANGELOG.md](apps/apple/CHANGELOG.md).

## spec 2 — 2026-11-16

### Added

- Record headers name the spec version the writer implements, as `specVersion` (engine.md › Records › Lines). Readers MUST accept records without it, written before spec 2. The golden record `seed1.jsonl` is re-recorded with it; its steps are unchanged.

## spec 1 — 2026-11-16

### Added

- The first versioned spec, covering rules `match-r23`: engine.md, ui.md (draft 1), the config files, and the fixtures with the `seed1.jsonl` golden record.
