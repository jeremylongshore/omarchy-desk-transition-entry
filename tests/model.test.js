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
    assert.deepEqual(Model.parse(value), { valid: false, monitors: [] })
  const oversizedValid = JSON.stringify({ monitors: [], padding: "x".repeat(Model.MAX_RAW_CHARS) })
  assert.deepEqual(Model.parse(oversizedValid), { valid: false, monitors: [] })
  const exact = '{"monitors":[]}' + " ".repeat(Model.MAX_RAW_CHARS - 15)
  assert.deepEqual(Model.parse(exact), { valid: true, monitors: [] })
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
