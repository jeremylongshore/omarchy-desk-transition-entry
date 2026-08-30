# Contributing

Desk Transition is intentionally local, bounded, and conservative. Changes to
display actions must continue to discover the current monitor inventory, pass
connector names as argv, and avoid every output-disable operation.

Install dependencies with `npm ci`. Before opening a pull request, run the full
denominator documented in `tests/TESTING.md`: tests and coverage, the repeated
race lane, mutation analysis, deterministic audit, npm audit, ShellCheck,
canonical freshness, and all plugin gates. Buzz E2E is required for runtime,
panel, helper, screenshot, or marketplace changes.

Do not hand-edit vendored gates. Use `scripts/sync-gate-lane.sh` against a clean
canonical contributing-clanker checkout. Do not commit a generated preview
until its `.render-proof.json` is current and hash-bound visual inspection has
been recorded.
