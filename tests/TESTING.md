# Testing Desk Transition

The release denominator is fail closed. `npm test` covers the JavaScript model,
QML contracts, accessibility surface, and the real Bash helper driven against a
stand-in `hyprctl`. `npm run test:race` repeats the suite with concurrent
workers. `npm run test:mutation` must clear the 90 percent break threshold.
`npm run audit`, ShellCheck, canonical lane freshness, and all vendored plugin
gates are required before Buzz.

## What the numbers were at 0.2.2

Derived from the final run, not copied from an older document:

- `npm test`: 49 tests, 0 failures. c8 reports 100 percent statements,
  branches, functions and lines on `Model.js` (floors 95, 90, 95, 95).
- `npm run test:race`: 3 runs of 49, 0 failures.
- `npm run test:mutation`: 97.51 percent on `Model.js` (196 killed, 5
  survived), break threshold 90. The survivors are equivalent mutants: three
  comparisons the preceding guard makes unreachable, and the
  `typeof module` export guard in both of its forms.
- Coverage and mutation cover `Model.js` only. The Bash helper, the QML and the
  rig scripts get neither signal, so the helper tests assert exact argv and exit
  statuses instead.
- CRAP is not enforced. The audit harness scores zero functions for a root-level
  `Model.js` and still reports PASS
  (jeremylongshore/intent-audit-harness#248), so no CRAP result is claimed here.
  The coordinator measures it separately.

## The stand-in hyprctl

`tests/hyprctl-stub.sh` answers the way Hyprland does, in two worlds, so the
helper's argv, success test and fallback order are tested against real replies
instead of an exit-0 stub. Each reply is cited to the Hyprland source in the
file's header.

- `lua` is Hyprland 0.57.2: `dispatch X` runs `return hl.dispatch(X)`, a Lua
  miss prints `warning: ...` and exits 0, a syntax error prints `error: ...` and
  exits 7, `eval` runs Lua and prints `ok`, and `keyword` does not exist (it
  prints `unknown request` and exits 0). `hl.monitor` merges the fields it is
  given into the output's existing rule, or starts from the defaults when the
  output has none.
- `classic` is Hyprland 0.54.3, the last release with a hyprlang config:
  `eval` is `unknown request`, a Lua dispatch is `Invalid dispatcher`,
  `focusmonitor` prints `ok`, and `keyword monitor` replaces the whole rule.

The helper tests fail on the 0.2.1 argv: running them against the 0.2.1 helper
(`DESK_TRANSITION_HELPER=<old helper> node --test tests/helper.test.js`) fails 14
of 18.

## Rig proof

`npm run test:e2e` ships the committed runtime to the isolated Buzz Omarchy
container. It validates and lints the exact source, loads a deterministic
two-output Hyprland fixture (a HiDPI laptop panel and a 1440p monitor) and the
stand-in `hyprctl` in its Lua world, invokes both real scene actions through
shell IPC, and checks that:

- Desk sent exactly one `hyprctl eval` placing both outputs, at the scaled
  positions `0x0` and `1440x0`;
- Laptop sent the Lua `hl.dsp.focus` form and the focus moved to `eDP-1`;
- no classic `keyword` or `focusmonitor` ran, because the Lua attempts returned
  `ok`;
- every output kept the mode and scale in its rule, and nothing was disabled;
- the real panel opened, and `preview.png` was captured directly at 1280 by 720.

Both receipts record the rig they ran on: Omarchy
`74de10479d3bf7aa7865408e33219064cfe45432`, qt6-base 6.12.0-5, Quickshell
0.3.2-1, hyprland package 0.57.2-1, qmllint 6.12.0. The preview remains
unapproved until the exact hash is inspected with `scripts/approve-preview.sh`;
the receipt names the inspector.

`OMARCHY_RIG_THEME=catppuccin-latte scripts/rig-render.sh . /tmp/latte.png`
renders the same run on a light theme, for looking at contrast. The committed
preview is tokyo-night. On catppuccin-latte the card titles are the theme
foreground (`#4c4f69`) on a card fill about 8 percent toward it from the popup
background, roughly 6:1, where the 0.2.1 fixed navy fill measured about 2:1.

One-off rig runs that are not committed: a render with `HOME` set to
`/tmp/dt home é%41-<run>` could not start the helper before 0.2.2 (the scan
failed with the path `.../dt home é%2541-.../bin/desk-transition`) and passes
after `Model.localPath`. A space and a non-ASCII letter were never the problem;
a literal percent sign, a hash or a question mark were.

## What is not proven

The rig has no live Hyprland. Its compositor is headless sway, so the Hyprland
behaviour is established from the v0.57.2 and v0.54.3 sources plus the stand-in
`hyprctl`, not by driving a compositor. Specifically unproven:

- that a real Hyprland 0.57.2 answers `ok` to these exact `hyprctl` calls on
  real hardware, and applies the new positions on the next frame;
- that a position-only `hl.monitor` keeps scale and mode for an output that has
  no connector-named rule. The source says it starts a new rule from the
  defaults (preferred mode, automatic scale), so an output set only by a
  wildcard `output = ""` or `desc:` rule in `hypr/monitors.lua` would lose that
  setting. Outputs with a connector-named rule, including everything the display
  panel saved, are merged.

## Live check on a real Omarchy laptop

On a laptop running Hyprland 0.57 or later, docked to one external monitor, run
the commands below. After Desk, every output must report the same width, height,
refreshRate, scale and transform as before, and x must run left to right, so the
second output's x equals the first output's width divided by its scale. After
Laptop the focused output must be the internal one, and after the row click the
external one. Each action must leave the panel saying "Scene applied", and the
`eval` line must print `ok`. To test the known limit, repeat the Desk step on a
laptop whose scale is set only by a wildcard `output = ""` rule in
`~/.config/hypr/monitors.lua`, and compare the scale before and after.

```bash
omarchy-plugin-add \
  https://github.com/jeremylongshore/omarchy-desk-transition-entry --enable
state() {
  hyprctl -j monitors \
    | jq -c '.[] | {name, width, height, refreshRate, scale, transform, x, y, focused}'
}
state
omarchy-shell io.github.jeremylongshore.desk-transition desk; sleep 1; state
omarchy-shell io.github.jeremylongshore.desk-transition laptop; sleep 1
hyprctl -j monitors | jq -r '.[] | select(.focused) | .name'
# click the external output's row in the panel, then:
hyprctl -j monitors | jq -r '.[] | select(.focused) | .name'
hyprctl eval 'hl.monitor({ output = "eDP-1", position = "0x0" })'
```
