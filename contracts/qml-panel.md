# Desk Transition QML Contract

`manifest.json`, `BarWidget.qml`, and `Panel.qml` share the exact module ID.
The bar widget injects the shell bar, settings, anchor, and host into the panel.
The panel exposes open, close, show, hide, toggle, refresh, Desk, and Laptop IPC
methods. Desk and Laptop actions call only the repository helper through an
argv array, report a bounded static outcome, and refresh the current inventory.

Every JavaScript model function referenced by production QML must exist on the
CommonJS export surface used by Node tests. `tests/contract.test.js` enforces
these relationships and the marketplace/render-proof contract.
