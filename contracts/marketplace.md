# Marketplace contract

Desk Transition ships one bar widget whose listing copy and runtime behavior
tell the same product story.

- Root and bar-widget descriptions are identical and exactly 500 characters.
- Copy distinguishes active outputs from physically connected displays, states
  the first-matching internal-panel behavior, names every visible panel field
  and action, and records the local/no-disable boundary.
- `assets/banner.svg` identifies Desk Transition and depicts discovered displays.
- `preview.png` is accepted only with current-tree Buzz provenance, exact
  1280x720 dimensions, a clean shell-log hash, and visual approval.
- The helper performs bounded local Hyprland reads, validates connector names,
  and never emits a display-disable command.

`tests/contract.test.js` and gate C43 enforce the machine-checkable portions.
