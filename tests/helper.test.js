const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const os = require("node:os")
const path = require("node:path")
const { execFile, execFileSync, spawnSync } = require("node:child_process")

const helper = process.env.DESK_TRANSITION_HELPER || path.join(__dirname, "..", "bin", "desk-transition")
const stub = path.join(__dirname, "hyprctl-stub.sh")

// A monitor as `hyprctl -j monitors all` reports it, with only the fields a test names changed.
function monitor(name, width, height, extra = {}) {
  return {
    name, width, height, refreshRate: 60, scale: 1, transform: 0, x: 0, y: 0,
    focused: false, disabled: false, mirrorOf: "none", ...extra,
  }
}

// `mode` is "lua" (Hyprland 0.57.2) or "classic" (Hyprland 0.54.3); see hyprctl-stub.sh.
function fixture(monitors, { mode = "lua", rules = {}, gone = "", evalFail = false } = {}) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "desk-transition-test-"))
  const bin = path.join(root, "bin")
  const log = path.join(root, "hyprctl.log")
  fs.mkdirSync(bin)
  fs.writeFileSync(path.join(root, "monitors.json"), JSON.stringify(monitors))
  fs.writeFileSync(path.join(root, "rules.json"), JSON.stringify(rules))
  fs.copyFileSync(stub, path.join(bin, "hyprctl"))
  fs.chmodSync(path.join(bin, "hyprctl"), 0o755)
  return {
    root,
    env: {
      ...process.env,
      PATH: `${bin}:${process.env.PATH}`,
      HYPRCTL_LOG: log,
      HYPRCTL_MONITORS: path.join(root, "monitors.json"),
      HYPRCTL_RULES: path.join(root, "rules.json"),
      HYPRCTL_MODE: mode,
      HYPRCTL_GONE: gone,
      ...(evalFail ? { HYPRCTL_EVAL_FAIL: "1" } : {}),
    },
    calls: () => fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean) : [],
    actions() { return this.calls().filter(call => !call.startsWith("-j ")) },
    rules: () => JSON.parse(fs.readFileSync(path.join(root, "rules.json"), "utf8")),
  }
}

function run(env, ...args) {
  return JSON.parse(execFileSync(helper, args, { encoding: "utf8", env }))
}

function attempt(env, ...args) {
  const result = spawnSync(helper, args, { encoding: "utf8", env })
  return { status: result.status, stdout: result.stdout, stderr: result.stderr }
}

function withRig(monitors, options, body) {
  const rig = fixture(monitors, options)
  try { return body(rig) } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
}

const laptopAndDesk = () => [
  monitor("eDP-1", 1920, 1080, { focused: true }),
  monitor("DP-1", 2560, 1440),
]

test("desk sends one Lua eval that places only the current active outputs left to right", () => {
  withRig(laptopAndDesk(), {}, rig => {
    assert.deepEqual(run(rig.env, "--desk"), { monitors: [
      { name: "eDP-1", width: 1920, height: 1080, focused: true },
      { name: "DP-1", width: 2560, height: 1440, focused: false },
    ], disabled: 0 })
    assert.deepEqual(rig.actions(), [
      'eval hl.monitor({ output = "eDP-1", position = "0x0" }) hl.monitor({ output = "DP-1", position = "1920x0" })',
    ])
  })
})

test("desk keeps each output's mode, refresh rate and scale because hl.monitor merges into its rule", () => {
  const rules = {
    "eDP-1": { mode: "2880x1800@120", scale: 2, position: "0x0" },
    "DP-1": { mode: "highrr", scale: 1, position: "auto" },
  }
  withRig([
    monitor("eDP-1", 2880, 1800, { refreshRate: 120.00001, scale: 2, focused: true }),
    monitor("DP-1", 2560, 1440, { refreshRate: 144 }),
  ], { rules }, rig => {
    run(rig.env, "--desk")
    assert.deepEqual(rig.rules(), {
      "eDP-1": { mode: "2880x1800@120", scale: 2, position: "0x0" },
      "DP-1": { mode: "highrr", scale: 1, position: "1440x0" },
    })
    assert.equal(rig.actions().some(call => call.startsWith("keyword ")), false)
  })
})

test("desk advances by scaled, rotated width, because positions are logical pixels", () => {
  withRig([
    monitor("eDP-1", 2880, 1800, { scale: 2, focused: true }),
    monitor("DP-1", 3840, 2160, { scale: 1.5 }),
    monitor("DP-2", 1080, 1920, { transform: 1 }),
    monitor("HDMI-A-1", 1920, 1080),
  ], {}, rig => {
    run(rig.env, "--desk")
    assert.deepEqual(rig.actions(), [
      'eval hl.monitor({ output = "eDP-1", position = "0x0" })'
      + ' hl.monitor({ output = "DP-1", position = "1440x0" })'
      + ' hl.monitor({ output = "DP-2", position = "4000x0" })'
      + ' hl.monitor({ output = "HDMI-A-1", position = "5920x0" })',
    ])
  })
})

test("desk leaves mirrors and disabled outputs out and reports how many are disabled", () => {
  withRig([
    monitor("eDP-1", 1920, 1080, { focused: true }),
    monitor("DP-1", 2560, 1440, { mirrorOf: "0" }),
    monitor("DP-2", 1920, 1080, { disabled: true }),
    monitor("DP-3", 1920, 1080, { disabled: true }),
    monitor("HDMI-A-1", 1280, 720),
  ], {}, rig => {
    const state = run(rig.env, "--desk")
    assert.deepEqual(state.monitors.map(entry => entry.name), ["eDP-1", "DP-1", "HDMI-A-1"])
    assert.equal(state.disabled, 2)
    assert.deepEqual(rig.actions(), [
      'eval hl.monitor({ output = "eDP-1", position = "0x0" }) hl.monitor({ output = "HDMI-A-1", position = "1920x0" })',
    ])
  })
})

test("desk on Hyprland with a classic config passes the current mode, scale and rotation back in", () => {
  const rules = { "eDP-1": { mode: "2880x1800@120", scale: "2", position: "0x0" } }
  withRig([
    monitor("eDP-1", 2880, 1800, { refreshRate: 120.00001, scale: 2, focused: true }),
    monitor("DP-1", 1440, 2560, { refreshRate: 59.95123, scale: 1.25, transform: 3 }),
  ], { mode: "classic", rules }, rig => {
    assert.deepEqual(run(rig.env, "--desk").monitors.length, 2)
    assert.deepEqual(rig.actions(), [
      'eval hl.monitor({ output = "eDP-1", position = "0x0" }) hl.monitor({ output = "DP-1", position = "1440x0" })',
      "keyword monitor eDP-1,2880x1800@120,0x0,2,transform,0",
      "keyword monitor DP-1,1440x2560@59.95,1440x0,1.25,transform,3",
    ])
    assert.equal(rig.actions().some(call => call.includes("preferred")), false)
    assert.deepEqual(rig.rules()["eDP-1"], { mode: "2880x1800@120", position: "0x0", scale: "2", transform: "0" })
  })
})

test("a Lua eval that fails is not retried as success when the classic form does not exist either", () => {
  withRig(laptopAndDesk(), { evalFail: true }, rig => {
    const result = attempt(rig.env, "--desk")
    assert.equal(result.status, 1)
    assert.match(result.stderr, /Hyprland did not arrange the displays/)
    assert.equal(JSON.parse(result.stdout).monitors.length, 2)
    assert.equal(rig.actions().filter(call => call.startsWith("keyword ")).length, 2)
  })
})

test("laptop focuses the internal display with the Lua form and stops there", () => {
  withRig([
    monitor("DP-1", 2560, 1440, { focused: true }),
    monitor("eDP-1", 1920, 1080),
  ], {}, rig => {
    const state = run(rig.env, "--laptop")
    assert.deepEqual(rig.actions(), ['dispatch hl.dsp.focus({ monitor = "eDP-1" })'])
    assert.deepEqual(state.monitors.map(entry => [entry.name, entry.focused]), [["DP-1", false], ["eDP-1", true]])
    assert.equal(rig.calls().some(call => call.includes("disable")), false)
  })
})

test("laptop falls back to the classic dispatcher when the Lua form is not understood", () => {
  withRig([monitor("LVDS-1", 1366, 768)], { mode: "classic" }, rig => {
    assert.equal(run(rig.env, "--laptop").monitors[0].focused, true)
    assert.deepEqual(rig.actions(), [
      'dispatch hl.dsp.focus({ monitor = "LVDS-1" })',
      "dispatch focusmonitor LVDS-1",
    ])
  })
})

test("a Lua miss that exits 0 with a warning is a failure, and so is the classic syntax error after it", () => {
  withRig([monitor("eDP-1", 1920, 1080)], { gone: "eDP-1" }, rig => {
    const result = attempt(rig.env, "--laptop")
    assert.equal(result.status, 1)
    assert.match(result.stderr, /Hyprland did not focus eDP-1/)
    assert.deepEqual(rig.actions(), [
      'dispatch hl.dsp.focus({ monitor = "eDP-1" })',
      "dispatch focusmonitor eDP-1",
    ])
  })
})

test("laptop and desk change nothing and say so when there is nothing to act on", () => {
  withRig([monitor("DP-1", 2560, 1440, { focused: true }), monitor("eDP-1", 1920, 1080, { disabled: true })], {}, rig => {
    const laptop = attempt(rig.env, "--laptop")
    assert.equal(laptop.status, 3)
    assert.match(laptop.stderr, /No active internal display/)
    assert.deepEqual(JSON.parse(laptop.stdout), { monitors: [
      { name: "DP-1", width: 2560, height: 1440, focused: true },
    ], disabled: 1 })
    assert.deepEqual(rig.actions(), [])
  })
  withRig([], {}, rig => {
    assert.equal(attempt(rig.env, "--desk").status, 3)
    assert.deepEqual(rig.actions(), [])
  })
})

test("focus rejects unknown names before dispatching and leaves the monitor state untouched", () => {
  withRig([monitor("HDMI-A-1", 1920, 1080, { focused: true })], {}, rig => {
    for (const hostile of ["HDMI-A-1;dispatch exit", 'HDMI-A-1" })', "", "DP-9"]) {
      assert.equal(attempt(rig.env, "--focus", hostile).status, 2, hostile)
    }
    assert.equal(rig.actions().length, 0)
    assert.equal(run(rig.env, "--focus", "HDMI-A-1").monitors.length, 1)
    assert.deepEqual(rig.actions(), ['dispatch hl.dsp.focus({ monitor = "HDMI-A-1" })'])
  })
})

test("a connector name that could break out of a Lua string never reaches hyprctl", () => {
  withRig([
    monitor("eDP-1", 1920, 1080, { focused: true }),
    monitor('DP-1" }) os.execute("x") --', 1920, 1080),
    monitor("DP-2\n", 1920, 1080),
    monitor("DP 3", 1920, 1080),
  ], {}, rig => {
    run(rig.env, "--desk")
    assert.deepEqual(rig.actions(), ['eval hl.monitor({ output = "eDP-1", position = "0x0" })'])
  })
})

test("scan bounds monitor count, connector length, and display geometry before QML", () => {
  withRig([
    ...Array.from({ length: 12 }, (_, index) => monitor(`DP-${index}`, 90000.9, -5)),
    monitor("x".repeat(33), 1, 1),
  ], {}, rig => {
    const state = run(rig.env, "--scan")
    assert.equal(state.monitors.length, 8)
    assert.deepEqual(state.monitors[0], { name: "DP-0", width: 20000, height: 0, focused: false })
  })
})

test("oversized hyprctl output fails closed before jq can buffer it", () => {
  withRig([monitor("DP-1", 1920, 1080, { title: "x".repeat(70000) })], {}, rig => {
    assert.deepEqual(run(rig.env, "--scan"), { monitors: [], disabled: 0 })
  })
})

test("a non-returning hyprctl scan is terminated by the production timeout", () => {
  withRig([], {}, rig => {
    fs.writeFileSync(path.join(rig.root, "bin", "hyprctl"), "#!/bin/sh\nsleep 10\n")
    const started = Date.now()
    assert.deepEqual(run(rig.env, "--scan"), { monitors: [], disabled: 0 })
    assert.ok(Date.now() - started < 5000)
  })
})

test("same-user concurrent scans are deterministic and read-only", async () => {
  const rig = fixture([monitor("eDP-1", 1920, 1080, { focused: true })])
  try {
    const outputs = await Promise.all(Array.from({ length: 8 }, () => new Promise((resolve, reject) => {
      execFile(helper, ["--scan"], { encoding: "utf8", env: rig.env }, (error, stdout) => {
        if (error) reject(error)
        else resolve(JSON.parse(stdout))
      })
    })))
    for (const output of outputs) assert.equal(output.monitors[0].name, "eDP-1")
    assert.deepEqual(rig.actions(), [])
  } finally { fs.rmSync(rig.root, { recursive: true, force: true }) }
})

test("an unknown helper argument is refused without touching hyprctl", () => {
  withRig(laptopAndDesk(), {}, rig => {
    assert.equal(attempt(rig.env, "--disable").status, 2)
    assert.deepEqual(rig.calls(), [])
  })
})

test("the stand-in hyprctl merges a position-only rule and records a mode or scale override as a change", () => {
  const rules = { "eDP-1": { mode: "2880x1800@120", scale: 2, position: "0x0" } }
  withRig([monitor("eDP-1", 2880, 1800)], { rules }, rig => {
    const hyprctl = path.join(rig.root, "bin", "hyprctl")
    const eval_ = code => execFileSync(hyprctl, ["eval", code], { encoding: "utf8", env: rig.env }).trim()
    assert.equal(eval_('hl.monitor({ output = "eDP-1", position = "10x0" })'), "ok")
    assert.deepEqual(rig.rules()["eDP-1"], { mode: "2880x1800@120", scale: 2, position: "10x0" })
    assert.equal(eval_('hl.monitor({ output = "eDP-1", mode = "preferred", position = "10x0", scale = 1 })'), "ok")
    assert.deepEqual(rig.rules()["eDP-1"], { mode: "preferred", scale: 1, position: "10x0" })
    assert.equal(eval_('hl.monitor({ output = "DP-9", position = "0x0" })'), "ok")
    assert.deepEqual(rig.rules()["DP-9"], { mode: "preferred", scale: "auto", position: "0x0" })
  })
})
