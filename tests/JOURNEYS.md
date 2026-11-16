# Acceptance Journeys

## Desk scene

Given two active outputs, opening the panel shows both resolutions and the
focused display. Applying Desk sends one Lua `hyprctl eval` that places each
current output left to right by scaled width, changing position only, then
refreshes inventory and reports success. On a release with no Lua it passes
each output's current mode, scale and rotation back in, one command per output.

## Laptop scene

Given an active eDP or LVDS output, applying Laptop revalidates the inventory,
focuses that internal output with `hl.dsp.focus` (or `focusmonitor` on an older
release), refreshes state, and never emits a disable action. With no active
internal output it changes nothing and says so.

## Hyprland refuses

A Lua miss prints a `warning:` and exits 0, a classic form on a Lua config
prints an `error:` and exits 7, and `keyword` answers `unknown request` with
exit 0. None of these is a success: the helper exits 1 and the panel says the
scene did not complete.

## Keyboard

Arrow keys or `h` `j` `k` `l` move between Desk, Laptop and each output. Enter
or Space applies the selected row. Nothing is selected when the panel opens.

## Failure and hostile inventory

Unknown connector names are rejected before dispatch. A slow or oversized
producer fails closed to an empty inventory. More than eight displays, overlong
names, duplicate names, and extreme geometry never cross the helper/model
boundary unbounded.

## Marketplace acceptance

The exact 500-character description, themed SVG banner, and visually approved
1280 by 720 Buzz preview must all match the committed evidence hashes before
C43 passes or an update request is created.
