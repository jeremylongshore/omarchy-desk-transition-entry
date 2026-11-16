# Desk Transition QML Contract

`manifest.json`, `BarWidget.qml`, and `Panel.qml` share the exact module ID.
The bar widget injects the shell bar, settings, anchor, and host into the panel.
The panel exposes open, close, show, hide, toggle, refresh, Desk, and Laptop IPC
methods.

Desk, Laptop and output-row actions call only the repository helper through an
argv array, report a bounded static outcome, and refresh the current inventory.
The helper exits 0 when Hyprland accepted the scene, 3 when no active display
matched, and 1 otherwise.

Every fill and outline comes from a theme token. Up, Down, Left, Right and
Enter reach every action through the key catcher's `activateRequested` alone.

Every JavaScript model function referenced by production QML must exist on the
CommonJS export surface used by Node tests. `tests/contract.test.js` enforces
these relationships and the marketplace/render-proof contract.
