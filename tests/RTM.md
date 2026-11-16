# Requirements Traceability Matrix

Each requirement is followed by the evidence that proves it. The Hyprland side
is proven from the Hyprland source and a stand-in `hyprctl`, not a live
compositor; see `tests/TESTING.md`.

- **Only current active outputs are targeted.**
  `helper.test.js` (disabled, mirrored and hostile outputs), rig action log.
- **Every action sends the Lua form first and the classic form second.**
  `helper.test.js` (Lua, classic and Lua-miss runs), `contract.test.js`, rig
  receipt `classicCommands == 0`.
- **An attempt succeeds only on the reply `ok` with exit status 0.**
  `helper.test.js` (a `warning:` exit 0, an `unknown request` exit 0, a syntax
  error exit 7), `contract.test.js`.
- **Desk changes position only, so each output keeps its mode, refresh rate,
  scale and rotation.**
  `helper.test.js` (rule merge model), `contract.test.js` (no `mode` or
  `scale` in a Lua rule), rig receipt `rulesKept`.
- **The classic fallback passes the current mode, refresh, scale and rotation.**
  `helper.test.js` (classic run, rules preserved, no `preferred`).
- **Desk advances by scaled, rotated width and places every output in one
  eval.**
  `helper.test.js` (HiDPI, fractional and rotated outputs), rig receipt
  `layout` and `deskEvals`.
- **Laptop focuses an internal panel and never disables an output.**
  `helper.test.js`, `contract.test.js`, rig action log.
- **A scene that Hyprland did not accept is reported, not hidden.**
  `helper.test.js` (exit 1 and exit 3), `contract.test.js` (status text).
- **Producer time, bytes, rows, names and geometry are bounded.**
  `helper.test.js`, `contract.test.js`, C42.
- **Unsafe or duplicate connector names are rejected before any Lua string.**
  `model.test.js`, `helper.test.js` (quote, newline and space names).
- **The footer is a live inventory reading.**
  `model.test.js`, `contract.test.js`.
- **Every fill and outline comes from the theme.**
  `contract.test.js`, light-theme render noted in `tests/TESTING.md`.
- **Every action is reachable by keyboard and by assistive technology.**
  `model.test.js` (selection and row actions), `contract.test.js`,
  `a11y.test.js`.
- **QML contracts and action outcomes remain wired.**
  `contract.test.js`.
- **Marketplace copy, banner and preview are exact artifacts.**
  `contract.test.js`, C43, `.render-proof.json`.
- **Real Omarchy accepts and renders the committed source.**
  `.rig-proof.json`, `.render-proof.json`, both recording the rig's Omarchy
  commit and Qt version.
