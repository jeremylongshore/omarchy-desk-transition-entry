const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const root = path.join(__dirname, "..")
const read = name => fs.readFileSync(path.join(root, name), "utf8")

test("bar control is a dynamically named accessible button", () => {
  const qml = read("BarWidget.qml")
  assert.match(qml, /Accessible\.role: Accessible\.Button/)
  assert.match(qml, /Accessible\.name: root\.opened \? "Close Desk Transition" : "Open Desk Transition"/)
})

test("both visual scene cards expose specific accessible actions", () => {
  const qml = read("Panel.qml")
  assert.equal((qml.match(/Accessible\.role: Accessible\.Button/g) || []).length, 2)
  assert.match(qml, /Accessible\.name: "Apply Desk scene"/)
  assert.match(qml, /Accessible\.name: "Apply Laptop scene"/)
  assert.match(qml, /onCloseRequested: root\.close\(\)/)
  assert.match(qml, /onTabRequested:/)
})

test("action status is wrapped, plain text, and announced", () => {
  const qml = read("Panel.qml")
  assert.match(qml, /text: root\.actionStatus/)
  assert.match(qml, /textFormat: Text\.PlainText/)
  assert.match(qml, /Accessible\.role: Accessible\.StaticText/)
  assert.match(qml, /Accessible\.name: root\.actionStatus/)
  assert.match(qml, /Accessible\.name: "Local inventory\. Zero outputs disabled\."/)
})
