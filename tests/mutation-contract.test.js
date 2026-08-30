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
    tooltip: [Model.tooltipText(valid), Model.tooltipText(null)]
  }, {
    constants: [8, 65536],
    clean: ["x", "ok"],
    dimensions: [0, 0, 3, 20000],
    valid: { valid: true, monitors: [
      { name: "eDP-1", focused: true, width: 1920, height: 1080 },
      { name: "DP-1", focused: false, width: 0, height: 20000 }
    ] },
    invalid: [false, false, false],
    pill: ["DESK 2", "DESK"],
    tooltip: ["2 connected displays", "No active displays reported"]
  })
})
