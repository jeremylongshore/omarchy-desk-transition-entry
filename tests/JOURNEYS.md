# Acceptance Journeys

## Desk scene

Given two active outputs, opening the panel shows both resolutions and the
focused display. Applying Desk emits one bounded `keyword monitor` command per
current output in left-to-right order, refreshes inventory, and reports success.

## Laptop scene

Given an active eDP or LVDS output, applying Laptop revalidates the inventory,
focuses that internal output, refreshes state, and never emits a disable action.

## Failure and hostile inventory

Unknown connector names are rejected before dispatch. A slow or oversized
producer fails closed to an empty inventory. More than eight displays, overlong
names, duplicate names, and extreme geometry never cross the helper/model
boundary unbounded.

## Marketplace acceptance

The exact 500-character description, themed SVG banner, and visually approved
1280 by 720 Buzz preview must all match the committed evidence hashes before
C43 passes or an update request is created.
