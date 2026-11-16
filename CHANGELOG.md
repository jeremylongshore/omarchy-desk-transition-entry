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

<!-- markdownlint-disable MD024 -->

## [0.2.2] - 2026-11-15

### Fixed

- Make Desk, Laptop and the row click work on Hyprland 0.57 with a Lua config.
  Every action used classic-only syntax: `hyprctl dispatch focusmonitor` is a
  Lua syntax error there, and `hyprctl keyword monitor` no longer exists (the
  server answers `unknown request` and hyprctl still exits 0), so each click
  reported "Scene did not complete" or, worse, applied nothing. Focus now sends
  `hl.dsp.focus({ monitor = ... })` first and `focusmonitor` second. Desk sends
  one `hyprctl eval` of position-only `hl.monitor` calls first and the classic
  `keyword monitor` second.
- Count an attempt as a success only when `hyprctl` prints `ok` and exits 0. A
  Lua miss prints a `warning:` and exits 0, and a classic form on a Lua config
  exits 7. The helper now exits 1 when Hyprland did not accept a scene, and 3
  when there was nothing to act on, instead of always reporting success.
- Stop Desk resetting each output to its preferred mode at scale 1. Position
  only changes the layout, so mode, refresh rate, scale and rotation stay. The
  classic fallback replaces a whole rule, so it passes the current
  mode@refresh, scale and rotation back in. Outputs advance by scaled, rotated
  width, because Hyprland positions are logical pixels, and outputs that mirror
  another are left out.
- Drop the constant "0 OUTPUTS DISABLED". The footer now reads the compositor
  for the active and disabled output counts, and says so while it is reading.
- Take every fill and outline from the theme. The fixed navy cards had about
  2:1 contrast on light themes such as catppuccin-latte.
- Reject connector names with a trailing newline. An anchored pattern lets `$`
  match before one, so the filter now refuses any character outside the
  connector alphabet.
- Find the helper when the install path holds a literal percent sign, a hash or
  a question mark. QUrl text keeps those escaped, so `dt%41` arrived as
  `dt%2541` and the scan never started. Spaces and non-ASCII letters were
  already fine. The panel now decodes the file URL before running the helper.
- Stop the README saying the preview had "human visual approval". The receipt
  records the inspector by name, and the README now says so.

### Added

- Reach every action from the keyboard: arrow keys or `h` `j` `k` `l` select
  Desk, Laptop or an output, Enter or Space applies it, and nothing is selected
  when the panel opens. Output rows and scene cards also answer the
  accessibility press action.
- A distinct status when no active display matched, such as Laptop on a machine
  with no internal panel.
- Record the rig's Omarchy commit and Qt version in `.rig-proof.json` and
  `.render-proof.json`, and a stand-in `hyprctl` (`tests/hyprctl-stub.sh`) that
  answers as Hyprland 0.57.2 and 0.54.3 do, used by the unit tests and the rig
  render alike.

### Changed

- Update the manifest copy, still exactly 500 characters, to say that Desk
  keeps each output's mode, refresh rate and scale, and that a click or a key
  focuses an output.
- Render the preview from a HiDPI laptop plus a 1440p monitor fixture, so the
  scaled layout is what the receipt records.
- Run ShellCheck on `bin/desk-transition` and the stand-in `hyprctl` in CI. The
  glob covered `scripts/`, `e2e/` and the hook but never the shipped helper.
- Re-sync the vendored gate lane to canonical `f79d8c7`, where C42 also scans
  shipped Perl helpers. The lane freshness check passes against it.

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
