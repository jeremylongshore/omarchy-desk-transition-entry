const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("clean removes markup, controls, and bidirectional overrides", () => {
  assert.equal(Model.clean("<b>a\x00b\u202ec</b>"), "babc/b")
  assert.equal(Model.clean(null), "")
  assert.equal(Model.clean(undefined), "")
})

test("clean enforces both default and explicit character caps", () => {
  assert.equal(Model.clean("x".repeat(50)).length, 32)
  assert.equal(Model.clean("abcdef", 2), "ab")
})

test("dimension normalizes finite integer display geometry", () => {
  assert.equal(Model.dimension(1920.9), 1920)
  assert.equal(Model.dimension(-1), 0)
  assert.equal(Model.dimension(30000), 20000)
  assert.equal(Model.dimension("bad"), 0)
  assert.equal(Model.dimension(Infinity), 0)
})

test("parse rejects absent, oversized, malformed, and non-array inventories", () => {
  for (const value of [undefined, null, "", "bad", JSON.stringify({ monitors: {} })])
    assert.deepEqual(Model.parse(value), { valid: false, monitors: [], disabled: 0 })
  const oversizedValid = JSON.stringify({ monitors: [], padding: "x".repeat(Model.MAX_RAW_CHARS) })
  assert.deepEqual(Model.parse(oversizedValid), { valid: false, monitors: [], disabled: 0 })
  const exact = '{"monitors":[]}' + " ".repeat(Model.MAX_RAW_CHARS - 15)
  assert.deepEqual(Model.parse(exact), { valid: true, monitors: [], disabled: 0 })
})

test("parse accepts safe unique monitor names and exact focus state", () => {
  const state = Model.parse(JSON.stringify({ monitors: [
    { name: "eDP-1", width: 1920, height: 1080, focused: true },
    { name: "DP-1", width: 2560, height: 1440 },
    { name: "bad;rm", width: 1 },
    { name: "DP-1", width: 1 }
  ] }))
  assert.equal(state.valid, true)
  assert.deepEqual(state.monitors, [
    { name: "eDP-1", focused: true, width: 1920, height: 1080 },
    { name: "DP-1", focused: false, width: 2560, height: 1440 }
  ])
})

test("parse rejects missing, non-string, and overlong connector names", () => {
  const state = Model.parse(JSON.stringify({ monitors: [
    null,
    { name: 3 },
    { name: "x".repeat(33) },
    { name: "y".repeat(32), width: 32, height: 32 },
    { name: "HDMI-A-1", focused: "yes" }
  ] }))
  assert.deepEqual(state.monitors, [
    { name: "y".repeat(32), focused: false, width: 32, height: 32 },
    { name: "HDMI-A-1", focused: false, width: 0, height: 0 }
  ])
})

test("parse caps inventory and hostile geometry", () => {
  const state = Model.parse(JSON.stringify({ monitors: Array.from({ length: 20 }, (_, index) => ({
    name: `DP-${index}`,
    width: 999999,
    height: -3
  })) }))
  assert.equal(state.monitors.length, Model.MAX_MONITORS)
  assert.equal(state.monitors[0].width, 20000)
  assert.equal(state.monitors[0].height, 0)
})

test("pill and tooltip copy cover empty and populated states", () => {
  assert.equal(Model.pillText(null), "DESK")
  assert.equal(Model.pillText({ monitors: [] }), "DESK")
  assert.equal(Model.pillText({ monitors: [{}] }), "DESK 1")
  assert.equal(Model.tooltipText(null), "No active displays reported")
  assert.equal(Model.tooltipText({ monitors: [] }), "No active displays reported")
  assert.equal(Model.tooltipText({ monitors: [{}, {}] }), "2 connected displays")
})

test("parse reads the disabled-output count and bounds it", () => {
  const read = disabled => Model.parse(JSON.stringify({ monitors: [], disabled })).disabled
  assert.equal(read(2), 2)
  assert.equal(read(2.9), 2)
  assert.equal(read(0), 0)
  assert.equal(read(-4), 0)
  assert.equal(read(500), Model.MAX_MONITORS)
  assert.equal(read("bad"), 0)
  assert.equal(read(null), 0)
  assert.equal(Model.parse(JSON.stringify({ monitors: [] })).disabled, 0)
})

test("inventory copy is a live reading, never a constant, and waits for the first scan", () => {
  const state = { monitors: [{}, {}], disabled: 1 }
  assert.equal(Model.inventoryText(state, true), "LOCAL INVENTORY  \u00b7  2 ACTIVE  \u00b7  1 DISABLED")
  assert.equal(Model.inventoryText({ monitors: [{}], disabled: 0 }, true), "LOCAL INVENTORY  \u00b7  1 ACTIVE  \u00b7  0 DISABLED")
  assert.equal(Model.inventoryText({ monitors: [] }, true), "LOCAL INVENTORY  \u00b7  0 ACTIVE  \u00b7  0 DISABLED")
  assert.equal(Model.inventoryText(state, false), "LOCAL INVENTORY  \u00b7  READING")
  assert.equal(Model.inventoryText(null, true), "LOCAL INVENTORY  \u00b7  READING")
  assert.equal(Model.inventoryText({}, true), "LOCAL INVENTORY  \u00b7  READING")
  assert.equal(Model.inventorySpoken(state, true), "Local inventory. Active outputs: 2. Disabled outputs: 1.")
  assert.equal(Model.inventorySpoken({ monitors: [] }, true), "Local inventory. Active outputs: 0. Disabled outputs: 0.")
  assert.equal(Model.inventorySpoken(state, false), "Local inventory. Reading displays.")
  assert.equal(Model.inventorySpoken(null, true), "Local inventory. Reading displays.")
  assert.equal(Model.inventorySpoken({}, true), "Local inventory. Reading displays.")
})

test("keyboard rows are the two scene cards then one per active output", () => {
  assert.equal(Model.rowCount(null), 2)
  assert.equal(Model.rowCount({}), 2)
  assert.equal(Model.rowCount({ monitors: [] }), 2)
  assert.equal(Model.rowCount({ monitors: [{}, {}, {}] }), 5)
})

test("selection starts empty, steps without wrapping, and survives a shrinking inventory", () => {
  assert.equal(Model.clampSelection(-1, 4), -1)
  assert.equal(Model.clampSelection(-5, 4), -1)
  assert.equal(Model.clampSelection(0, 4), 0)
  assert.equal(Model.clampSelection(3, 4), 3)
  assert.equal(Model.clampSelection(9, 4), 3)
  assert.equal(Model.clampSelection(0, 0), -1)
  assert.equal(Model.clampSelection(2, -1), -1)
  assert.equal(Model.moveSelection(-1, 4, 0, 1), 0)
  assert.equal(Model.moveSelection(-1, 4, 1, 0), 0)
  assert.equal(Model.moveSelection(-1, 4, 0, -1), 3)
  assert.equal(Model.moveSelection(-1, 4, -1, 0), 3)
  assert.equal(Model.moveSelection(0, 4, 0, 1), 1)
  assert.equal(Model.moveSelection(1, 4, 1, 0), 2)
  assert.equal(Model.moveSelection(2, 4, 0, -1), 1)
  assert.equal(Model.moveSelection(2, 4, -1, 0), 1)
  assert.equal(Model.moveSelection(3, 4, 0, 1), 3)
  assert.equal(Model.moveSelection(0, 4, 0, -1), 0)
  assert.equal(Model.moveSelection(2, 4, 0, 0), 2)
  assert.equal(Model.moveSelection(9, 4, 0, 0), 3)
  assert.equal(Model.moveSelection(1, 0, 0, 1), -1)
  assert.equal(Model.moveSelection(0, 4, 3, 0), 1)
  assert.equal(Model.moveSelection(1, 4, 0, -3), 0)
})

test("each keyboard row maps to exactly one helper action, and a vanished row to none", () => {
  const state = { monitors: [{ name: "eDP-1" }, { name: "DP-1" }] }
  assert.deepEqual(Model.actionArgs(0, state), ["--desk"])
  assert.deepEqual(Model.actionArgs(1, state), ["--laptop"])
  assert.deepEqual(Model.actionArgs(2, state), ["--focus", "eDP-1"])
  assert.deepEqual(Model.actionArgs(3, state), ["--focus", "DP-1"])
  assert.equal(Model.actionArgs(4, state), null)
  assert.equal(Model.actionArgs(-1, state), null)
  assert.equal(Model.actionArgs(2, null), null)
  assert.equal(Model.actionArgs(2, {}), null)
  assert.deepEqual(Model.actionArgs(0, null), ["--desk"])
})

test("localPath turns a file URL into the path, undoing the escapes QUrl keeps", () => {
  assert.equal(Model.localPath("file:///home/jeremy/.config/omarchy/plugins/x/bin/h"), "/home/jeremy/.config/omarchy/plugins/x/bin/h")
  assert.equal(Model.localPath("file:///tmp/dt home \u00e9%2541-1/bin/h"), "/tmp/dt home \u00e9%41-1/bin/h")
  assert.equal(Model.localPath("file:///a%23b%3Fc"), "/a#b?c")
  assert.equal(Model.localPath("file:///a%E9b"), "/a%E9b")
  assert.equal(Model.localPath("/already/plain"), "/already/plain")
  assert.equal(Model.localPath("xfile:///a"), "xfile:///a")
  assert.equal(Model.localPath("file:///file:///a"), "/file:///a")
})
