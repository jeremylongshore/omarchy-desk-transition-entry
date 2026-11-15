# Changelog

Notable changes to this plugin.

Entries are derived from this repository's commit history, so every line
corresponds to a real change. The format follows Keep a Changelog and the
project uses Semantic Versioning.

Regenerate after a release with:

```bash
scripts/gen-changelog.py . "<Plugin Name>" "<version>"
```

The generator normalises em and en dashes, because a changelog is shipped prose
and gate c28 refuses them.

## [0.2.1] - 2026-11-15

### Fixed

- Qualify Omarchy's palette as `Commons.Color`, as the shell contract requires
  now that Qt 6.12 has its own `Color` type. A contract test fails on any bare
  `Color.` in the shipped QML.

### Changed

- Seed the rig render's isolated home with the current-theme state a real
  Omarchy install has, so first-party shell plugins on current Omarchy do not
  log warnings the render would read as plugin warnings.
- Bump `actions/setup-node` to 7.1.0 and the MiniMax review action to the
  fork's current main (`cfb2c72`), with the audit harness re-pinned.

## [0.2.0] - 2026-08-29

### Changed

- Added exact marketplace copy, isolated Buzz action/render proof, and explicit
  hash-bound visual approval.
- Bounded Hyprland discovery by time, bytes, rows, connector length, and display
  geometry.
- Added visible action outcomes, accessibility contracts, mutation analysis,
  race runs, deterministic audit, ShellCheck, and current C28 through C43 gates.

## [0.1.0] - 2026-08-28

### Added

- Initial plugin.
