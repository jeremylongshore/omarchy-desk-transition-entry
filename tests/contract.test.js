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
    "active outputs", "scaled width", "mode, refresh rate, and scale",
    "first active eDP or LVDS output",
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
  assert.match(helper, /timeout 3s hyprctl -j monitors all/)
  assert.match(helper, /head -c 65537/)
  assert.match(helper, /\$\{#raw\} <= 65536/)
  assert.match(helper, /\.\[0:8\]/)
  assert.match(helper, /\.name \| length\) <= 32/)
  assert.match(helper, /elif \. > 20000 then 20000/)
  assert.doesNotMatch(helper, /curl|wget|https?:\/\//)
  // The helper reads which outputs the system disabled, but never sends a disable.
  assert.doesNotMatch(helper, /disabled\s*=\s*true|,\s*disable\b|monitor\s+\S+,\s*disable/)
})

test("the panel resolves the helper through Model.localPath, not a bare prefix strip", () => {
  const panel = read("Panel.qml")
  assert.match(panel, /helperPath: Model\.localPath\(Qt\.resolvedUrl\("bin\/desk-transition"\)\.toString\(\)\)/)
  assert.doesNotMatch(panel, /\.replace\(\/\^file/)
})

test("every hyprctl action sends the Lua form first and accepts only an exact ok", () => {
  const helper = read("bin/desk-transition")
  assert.match(helper, /hypr_ok dispatch "hl\.dsp\.focus\(\{ monitor = \\"\$name\\" \}\)"/)
  assert.match(helper, /\|\| hypr_ok dispatch focusmonitor "\$name"/)
  assert.match(helper, /hypr_ok eval "\$\{expr% \}"/)
  assert.match(helper, /hl\.monitor\(\{ output = \\"\$name\\", position = \\"\$position\\" \}\)/)
  assert.match(helper, /"\$out" == "ok"/)
  assert.match(helper, /"\$rc" -eq 0/)
  // Position only: a Lua rule that names mode or scale would reset what the user chose.
  assert.doesNotMatch(helper, /hl\.monitor\([^)]*\b(mode|scale|transform)\s*=/)
  // The classic fallback replaces the whole rule, so it must carry the current mode, scale and rotation.
  assert.match(helper, /hypr_ok keyword monitor "\$name,\$mode,\$position,\$scale,transform,\$turn"/)
  assert.doesNotMatch(helper, /preferred/)
})

test("the panel exposes explicit action outcomes and live E2E controls", () => {
  const panel = read("Panel.qml")
  assert.match(panel, /Scene applied\. Active display state refreshed\./)
  assert.match(panel, /Scene did not complete\. Active display state refreshed\./)
  assert.match(panel, /No matching active display, so nothing changed\./)
  assert.match(panel, /code === 3/)
  assert.match(panel, /function desk\(\): void/)
  assert.match(panel, /function laptop\(\): void/)
})

test("the inventory footer is a live reading, not a constant", () => {
  const panel = read("Panel.qml")
  assert.match(panel, /text: Model\.inventoryText\(root\.state, root\.loaded\)/)
  assert.match(panel, /Accessible\.name: Model\.inventorySpoken\(root\.state, root\.loaded\)/)
  assert.doesNotMatch(panel, /0 OUTPUTS DISABLED/)
})

test("the panel takes every fill and outline from the theme, never a fixed colour", () => {
  for (const file of ["Panel.qml", "BarWidget.qml"]) {
    const source = read(file)
    assert.doesNotMatch(source, /#[0-9a-fA-F]{3,8}\b/, file + " hard-codes a hex colour")
    assert.doesNotMatch(source, /Qt\.(hsla|hsva|rgba)\(/, file + " hard-codes a colour")
  }
  assert.match(read("Panel.qml"), /Style\.hoverFillFor\(root\.ink, Commons\.Color\.accent\)/)
})

test("the keyboard reaches every action through the catcher's activateRequested alone", () => {
  const panel = read("Panel.qml")
  assert.match(panel, /onMoveRequested: function\(dx, dy\)/)
  assert.match(panel, /onActivateRequested: root\.activateSelected\(\)/)
  // returnRequested fires just before activateRequested on Return; wiring both runs a scene twice.
  assert.doesNotMatch(panel, /onReturnRequested|onTextKey|onDeleteRequested/)
  assert.match(panel, /Model\.actionArgs\(root\.selected, root\.state\)/)
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

test("QML qualifies Omarchy's palette as Commons.Color, never bare Color", () => {
  // Qt 6.12 introduces its own Color type; omarchy docs/omarchy-shell.md
  // (Theme tokens) requires plugins to import qs.Commons with an alias.
  const files = fs.readdirSync(root).filter(name => name.endsWith(".qml"))
  assert.ok(files.length > 0)
  for (const file of files) {
    const source = fs.readFileSync(path.join(root, file), "utf8")
    assert.doesNotMatch(source, /(^|[^\w.])Color\./m, file + " uses bare Color")
    if (/Commons\.Color\./.test(source)) assert.match(source, /^import qs\.Commons as Commons$/m, file)
  }
})
