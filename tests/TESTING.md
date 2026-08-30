# Testing Desk Transition

The release denominator is fail closed. `npm test` covers the JavaScript model,
QML contracts, accessibility surface, and the real Bash helper. `npm run
test:race` repeats the suite with concurrent workers. `npm run test:mutation`
must clear the 90 percent break threshold. `npm run audit`, ShellCheck, canonical
lane freshness, and all vendored plugin gates are required before Buzz.

`npm run test:e2e` ships the committed runtime to the isolated Buzz Omarchy
container. It validates and lints the exact source, loads a deterministic
two-output Hyprland fixture through the unchanged helper, invokes both real
scene actions through shell IPC, verifies the expected Hyprland commands and
absence of disable commands, opens the real panel, and captures `preview.png`
directly at 1280 by 720. The preview remains unapproved until a person inspects
the exact hash with `scripts/approve-preview.sh`.

The audit harness can emit tool-availability advisories. Those do not replace
the explicit accessibility tests, npm audit, ShellCheck, Buzz proof, or C43.
