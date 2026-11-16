const test = require("node:test")
const assert = require("node:assert/strict")
const Model = require("../Model.js")

test("complete exported model contract has a deterministic mutation signature", () => {
  const valid = Model.parse(JSON.stringify({ monitors: [
    { name: "eDP-1", width: 1920.8, height: 1080, focused: true },
    { name: "DP-1", width: -1, height: 50000, focused: false }
  ] }))
  assert.deepEqual({
    constants: [Model.MAX_MONITORS, Model.MAX_RAW_CHARS],
    clean: [Model.clean("<x\u202e>", 1), Model.clean("ok")],
    dimensions: [Model.dimension(NaN), Model.dimension(-1), Model.dimension(3.9), Model.dimension(20001)],
    valid,
    invalid: [Model.parse("").valid, Model.parse("{").valid, Model.parse('{"monitors":null}').valid],
    pill: [Model.pillText(valid), Model.pillText(null)],
    tooltip: [Model.tooltipText(valid), Model.tooltipText(null)],
    paths: [Model.localPath("file:///a b/%2541"), Model.localPath("file:///a%E9"), Model.localPath("/p"), Model.localPath("xfile:///a")],
    disabled: [Model.parse('{"monitors":[],"disabled":3.7}').disabled, Model.parse('{"monitors":[],"disabled":99}').disabled,
      Model.parse('{"monitors":[],"disabled":-1}').disabled, Model.parse('{"monitors":[]}').disabled],
    inventory: [Model.inventoryText(valid, true), Model.inventoryText(valid, false),
      Model.inventorySpoken(valid, true), Model.inventorySpoken(valid, false)],
    rows: [Model.rowCount(valid), Model.rowCount(null)],
    selection: [Model.clampSelection(7, 4), Model.clampSelection(-1, 4), Model.clampSelection(-5, 4), Model.clampSelection(0, 4), Model.moveSelection(-1, 4, 0, 1),
      Model.moveSelection(-1, 4, 0, -1), Model.moveSelection(1, 4, 1, 0), Model.moveSelection(1, 4, 0, -1),
      Model.moveSelection(3, 4, 0, 1), Model.moveSelection(0, 4, 0, -1), Model.moveSelection(2, 0, 0, 1)],
    actions: [Model.actionArgs(0, valid), Model.actionArgs(1, valid), Model.actionArgs(3, valid), Model.actionArgs(4, valid)]
  }, {
    constants: [8, 65536],
    clean: ["x", "ok"],
    dimensions: [0, 0, 3, 20000],
    valid: { valid: true, disabled: 0, monitors: [
      { name: "eDP-1", focused: true, width: 1920, height: 1080 },
      { name: "DP-1", focused: false, width: 0, height: 20000 }
    ] },
    invalid: [false, false, false],
    pill: ["DESK 2", "DESK"],
    tooltip: ["2 connected displays", "No active displays reported"],
    paths: ["/a b/%41", "/a%E9", "/p", "xfile:///a"],
    disabled: [3, 8, 0, 0],
    inventory: [
      "LOCAL INVENTORY  \u00b7  2 ACTIVE  \u00b7  0 DISABLED",
      "LOCAL INVENTORY  \u00b7  READING",
      "Local inventory. Active outputs: 2. Disabled outputs: 0.",
      "Local inventory. Reading displays."
    ],
    rows: [4, 2],
    selection: [3, -1, -1, 0, 0, 3, 2, 0, 3, 0, -1],
    actions: [["--desk"], ["--laptop"], ["--focus", "DP-1"], null]
  })
})
