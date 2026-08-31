const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const root = path.join(__dirname, "..")
const read = name => fs.readFileSync(path.join(root, name), "utf8")
const Model = require("../Model.js")

test("every Model function called by production QML exists", () => {
  const qml = ["Panel.qml"].map(read).join("\n")
  const called = [...qml.matchAll(/Model\.([A-Za-z][A-Za-z0-9_]*)\s*\(/g)].map(match => match[1])
  assert.ok(called.length > 0)
  for (const name of new Set(called)) assert.equal(typeof Model[name], "function", name)
})

test("manifest and QML entry points share one exact module id", () => {
  const manifest = JSON.parse(read("manifest.json"))
  const escaped = manifest.id.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  for (const file of ["BarWidget.qml", "Panel.qml"])
    assert.match(read(file), new RegExp(`moduleName: "${escaped}"`))
  for (const entry of Object.values(manifest.entryPoints))
    assert.equal(fs.statSync(path.join(root, entry)).isFile(), true)
})

test("marketplace copy and authored banner are exact release artifacts", () => {
  const manifest = JSON.parse(read("manifest.json"))
  assert.equal(manifest.description.length, 500)
  assert.equal(manifest.barWidget.description.length, 500)
  assert.equal(manifest.description, manifest.barWidget.description)
  for (const claim of [
    "active outputs", "reported width", "first active eDP or LVDS output",
    "without disabling another screen", "name, resolution, and focus state",
    "validates output names", "No network, credentials, or display-disable command"
  ]) assert.match(manifest.description, new RegExp(claim))
  const banner = read("assets/banner.svg")
  assert.match(banner, /<title id="title">Desk Transition<\/title>/)
  assert.match(banner, /DISCOVERED DISPLAYS, SAFER SCENES/)
  assert.match(banner, /<(?:rect|path)\b/)
})

test("the runtime helper bounds producer time, bytes, rows, names, and dimensions", () => {
  const helper = read("bin/desk-transition")
  assert.match(helper, /timeout 3s hyprctl -j monitors/)
  assert.match(helper, /head -c 65537/)
  assert.match(helper, /\$\{#raw\} <= 65536/)
  assert.match(helper, /limit\(8; \.\[\]/)
  assert.match(helper, /\.name \| length\) <= 32/)
  assert.match(helper, /elif \. > 20000 then 20000/)
  assert.doesNotMatch(helper, /disable|curl|wget|https?:\/\//)
})

test("the panel exposes explicit action outcomes and live E2E controls", () => {
  const panel = read("Panel.qml")
  assert.match(panel, /Scene applied\. Active display state refreshed\./)
  assert.match(panel, /Scene did not complete\. Active display state refreshed\./)
  assert.match(panel, /function desk\(\): void/)
  assert.match(panel, /function laptop\(\): void/)
  assert.match(panel, /LOCAL INVENTORY  ·  0 OUTPUTS DISABLED/)
})

test("render tooling requires isolated provenance and exact visual approval", () => {
  const render = read("scripts/rig-render.sh")
  assert.match(render, /OMARCHY_RIG_RESOLUTION:-1280x720/)
  assert.match(render, /OMARCHY_RIG_SCALE:-1\.25/)
  assert.match(render, /rawShellLogSha256/)
  assert.match(render, /visualInspection:\{status:"pending"/)
  assert.match(render, /grim "\\\$SHOT"/)
  assert.doesNotMatch(render, /grim -g|pkill/)
  const approval = read("scripts/approve-preview.sh")
  assert.match(approval, /product value is visible without reading the README/)
})

test("canonical freshness uses a shallow clone and no downloader execution pattern", () => {
  const freshness = read("scripts/check-lane-freshness.sh")
  assert.match(freshness, /git clone --quiet --depth 1 --branch/)
  assert.doesNotMatch(freshness, /\bcurl\b|\bwget\b/)
})
