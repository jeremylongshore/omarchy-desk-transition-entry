# Requirements Traceability Matrix

| Requirement | Evidence |
| --- | --- |
| Only current active outputs are targeted | `helper.test.js`, Buzz fixture action log |
| Desk lays outputs left to right | `helper.test.js`, Buzz `keyword monitor` assertions |
| Laptop focuses an internal panel | `helper.test.js`, Buzz `focusmonitor` assertion |
| No scene disables an output | helper source/contract tests, Buzz negative assertion |
| Producer time, bytes, rows, names, and geometry are bounded | `helper.test.js`, `contract.test.js`, C42 |
| Unsafe or duplicate connector names are rejected | `model.test.js`, `helper.test.js` |
| QML contracts and action outcomes remain wired | `contract.test.js` |
| Scene controls and outcome status are accessible | `a11y.test.js` |
| Marketplace copy, banner, and preview are exact artifacts | `contract.test.js`, C43, `.render-proof.json` |
| Real Omarchy accepts and renders the committed source | `.rig-proof.json`, `.render-proof.json` |
