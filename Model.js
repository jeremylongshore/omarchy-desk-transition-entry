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
  return { valid: false, monitors: [] }
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
  return { valid: true, monitors: monitors }
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

if (typeof module !== "undefined") {
  module.exports = {
    MAX_MONITORS: MAX_MONITORS,
    MAX_RAW_CHARS: MAX_RAW_CHARS,
    clean: clean,
    dimension: dimension,
    parse: parse,
    pillText: pillText,
    tooltipText: tooltipText
  }
}
