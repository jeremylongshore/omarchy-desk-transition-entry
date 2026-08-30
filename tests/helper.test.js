const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { execFile, execFileSync, spawnSync } = require("node:child_process")

const helper = path.join(__dirname, "..", "bin", "desk-transition")

function fixture(monitors) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "desk-transition-test-"))
  const bin = path.join(root, "bin")
  const log = path.join(root, "hyprctl.log")
  fs.mkdirSync(bin)
  fs.writeFileSync(path.join(root, "monitors.json"), JSON.stringify(monitors))
  fs.writeFileSync(path.join(bin, "hyprctl"), `#!/bin/sh
printf '%s\\n' "$*" >> "$HYPRCTL_LOG"
if [ "$1" = "-j" ] && [ "$2" = "monitors" ]; then cat "$HYPRCTL_MONITORS"; fi
`)
  fs.chmodSync(path.join(bin, "hyprctl"), 0o755)
  return {
    root,
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      HYPRCTL_LOG: log,
      HYPRCTL_MONITORS: path.join(root, "monitors.json"),
    },
    calls: () => fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean) : [],
  }
}

function run(env, ...args) {
  return JSON.parse(execFileSync(helper, args, { encoding: "utf8", env }))
}

test("desk arranges only the current active monitor inventory in horizontal order", () => {
  const rig = fixture([
    { name: "eDP-1", width: 1920, height: 1080, focused: true },
    { name: "DP-1", width: 2560, height: 1440, focused: false },
  ])
  try {
    assert.deepEqual(run(rig.env, "--desk"), { monitors: [
      { name: "eDP-1", width: 1920, height: 1080, focused: true },
      { name: "DP-1", width: 2560, height: 1440, focused: false },
    ] })
    assert.deepEqual(rig.calls().filter(call => !call.startsWith("-j ")), [
      "keyword monitor eDP-1,preferred,0x0,1",
      "keyword monitor DP-1,preferred,1920x0,1",
    ])
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("laptop focuses a detected internal display and never disables an output", () => {
  const rig = fixture([{ name: "eDP-1", width: 1920, height: 1080, focused: false }])
  try {
    assert.equal(run(rig.env, "--laptop").monitors.length, 1)
    assert.deepEqual(rig.calls().filter(call => !call.startsWith("-j ")), ["dispatch focusmonitor eDP-1"])
    assert.equal(rig.calls().some(call => call.includes("disable")), false)
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("focus rejects unknown names before dispatching and leaves the monitor state untouched", () => {
  const rig = fixture([{ name: "HDMI-A-1", width: 1920, height: 1080, focused: true }])
  try {
    const result = spawnSync(helper, ["--focus", "HDMI-A-1;dispatch exit"], { encoding: "utf8", env: rig.env })
    assert.equal(result.status, 2)
    assert.equal(rig.calls().some(call => call.startsWith("dispatch ")), false)
    assert.equal(run(rig.env, "--focus", "HDMI-A-1").monitors.length, 1)
    assert.deepEqual(rig.calls().filter(call => call.startsWith("dispatch ")), ["dispatch focusmonitor HDMI-A-1"])
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("scan bounds monitor count, connector length, and display geometry before QML", () => {
  const rig = fixture([
    ...Array.from({ length: 12 }, (_, index) => ({ name: `DP-${index}`, width: 90000.9, height: -5 })),
    { name: "x".repeat(33), width: 1, height: 1 },
  ])
  try {
    const state = run(rig.env, "--scan")
    assert.equal(state.monitors.length, 8)
    assert.deepEqual(state.monitors[0], { name: "DP-0", width: 20000, height: 0, focused: false })
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("oversized hyprctl output fails closed before jq can buffer it", () => {
  const rig = fixture([{ name: "DP-1", width: 1920, height: 1080, title: "x".repeat(70000) }])
  try {
    assert.deepEqual(run(rig.env, "--scan"), { monitors: [] })
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("a non-returning hyprctl scan is terminated by the production timeout", () => {
  const rig = fixture([])
  try {
    fs.writeFileSync(path.join(rig.root, "bin", "hyprctl"), "#!/bin/sh\nsleep 10\n")
    const started = Date.now()
    assert.deepEqual(run(rig.env, "--scan"), { monitors: [] })
    assert.ok(Date.now() - started < 5000)
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("same-user concurrent scans are deterministic and read-only", async () => {
  const rig = fixture([{ name: "eDP-1", width: 1920, height: 1080, focused: true }])
  try {
    const outputs = await Promise.all(Array.from({ length: 8 }, () => new Promise((resolve, reject) => {
      execFile(helper, ["--scan"], { encoding: "utf8", env: rig.env }, (error, stdout) => {
        if (error) reject(error)
        else resolve(JSON.parse(stdout))
      })
    })))
    for (const output of outputs) assert.equal(output.monitors[0].name, "eDP-1")
    assert.equal(rig.calls().some(call => !call.startsWith("-j ")), false)
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})
