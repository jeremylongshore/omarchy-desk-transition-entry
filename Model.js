var MAX_MONITORS = 8
var MAX_RAW_CHARS = 65536

function clean(value, max) {
  var text = String(value === undefined || value === null ? "" : value)
    .replace(/[<>]/g, "")
    .replace(/[\x00-\x1f\x7f]/g, "")
    .replace(/[\u202a-\u202e\u2066-\u2069]/g, "")
  var cap = max || 32
  return text.slice(0, cap)
}

function dimension(value) {
  var number = Number(value)
  if (!isFinite(number)) return 0
  return Math.max(0, Math.min(20000, Math.floor(number)))
}

function invalidState() {
  return { valid: false, monitors: [], disabled: 0 }
}

function parse(raw) {
  var text = String(raw)
  if (text.length > MAX_RAW_CHARS) return invalidState()
  var input
  try {
    input = JSON.parse(text)
    if (!input || !Array.isArray(input.monitors)) return invalidState()
  } catch (error) { return invalidState() }

  var monitors = []
  var seen = ({})
  input.monitors.forEach(function(candidate) {
    if (monitors.length >= MAX_MONITORS) return
    var monitor = candidate || ({})
    if (typeof monitor.name !== "string"
        || monitor.name.length > 32
        || !/^[A-Za-z0-9._-]+$/.test(monitor.name)
        || seen[monitor.name]) return
    seen[monitor.name] = true
    monitors.push({
      name: clean(monitor.name, 32),
      focused: monitor.focused === true,
      width: dimension(monitor.width),
      height: dimension(monitor.height)
    })
  })
  return { valid: true, monitors: monitors, disabled: Math.min(MAX_MONITORS, dimension(input.disabled)) }
}

function pillText(state) {
  return state && state.monitors && state.monitors.length
    ? "DESK " + state.monitors.length : "DESK"
}

function tooltipText(state) {
  return state && state.monitors && state.monitors.length
    ? state.monitors.length + " connected displays"
    : "No active displays reported"
}

// The local path of a file URL. QUrl text keeps a literal percent sign (and a
// hash or a question mark) escaped, so "dt%41" arrives as "dt%2541" and the
// helper would not be found. Spaces and non-ASCII letters arrive already plain.
function localPath(url) {
  var text = String(url).replace(/^file:\/\//, "")
  try { return decodeURIComponent(text) } catch (error) { return text }
}

// The panel footer reads the compositor's own inventory: how many outputs are
// active and how many the system has turned off (a closed lid, for one). It
// never claims a count before the first scan has answered.
function inventoryText(state, loaded) {
  if (!loaded || !state || !state.monitors) return "LOCAL INVENTORY  \u00b7  READING"
  return "LOCAL INVENTORY  \u00b7  " + state.monitors.length + " ACTIVE  \u00b7  "
    + (state.disabled || 0) + " DISABLED"
}

function inventorySpoken(state, loaded) {
  if (!loaded || !state || !state.monitors) return "Local inventory. Reading displays."
  return "Local inventory. Active outputs: " + state.monitors.length
    + ". Disabled outputs: " + (state.disabled || 0) + "."
}

// Keyboard rows, in reading order: the Desk card, the Laptop card, then one row
// per active output.
function rowCount(state) {
  return 2 + (state && state.monitors ? state.monitors.length : 0)
}

// -1 means nothing is selected, so Enter on a freshly opened panel does nothing.
function clampSelection(index, count) {
  if (count <= 0 || index < 0) return -1
  return Math.min(index, count - 1)
}

// Down and Right step forward, Up and Left step back. From nothing, forward
// lands on the first row and back on the last. The ends do not wrap.
function moveSelection(index, count, dx, dy) {
  if (count <= 0) return -1
  var step = dy !== 0 ? dy : dx
  if (step === 0) return clampSelection(index, count)
  if (index < 0) return step > 0 ? 0 : count - 1
  return Math.max(0, Math.min(count - 1, index + (step > 0 ? 1 : -1)))
}

// The helper arguments one row applies, or null when the row is gone.
function actionArgs(index, state) {
  if (index === 0) return ["--desk"]
  if (index === 1) return ["--laptop"]
  var monitor = state && state.monitors ? state.monitors[index - 2] : null
  return monitor ? ["--focus", monitor.name] : null
}

if (typeof module !== "undefined") {
  module.exports = {
    MAX_MONITORS: MAX_MONITORS,
    MAX_RAW_CHARS: MAX_RAW_CHARS,
    clean: clean,
    dimension: dimension,
    parse: parse,
    pillText: pillText,
    tooltipText: tooltipText,
    localPath: localPath,
    inventoryText: inventoryText,
    inventorySpoken: inventorySpoken,
    rowCount: rowCount,
    clampSelection: clampSelection,
    moveSelection: moveSelection,
    actionArgs: actionArgs
  }
}
