# Contributing

> **Maintainers wanted.** We are looking for dependable Omarchy users who want
> to review issues, test releases, and keep a plugin healthy over time. Start
> with a small pull request or open an issue titled **Maintainer interest**.
> Consistent contributors can earn maintainer responsibility.

## Verification responsibility

Documentation-only changes run the portable content gates:

```bash
scripts/run-plugin-gates.sh .
```

Changes to code, tests, manifests, automation, or runtime behavior also run:

```bash
npm ci
npm test
```

CI performs the remaining race, mutation, audit, and shell checks. For visible
changes, include a screenshot and describe what you exercised. Contributors do
not need private Buzz access. A maintainer performs trusted real-shell
verification after code review.

Do not edit `.rig-proof.json`, `.render-proof.json`, `preview.png`, or files
under `scripts/gates/`. Those are maintainer-owned or canonical evidence.

## Project-specific guidance

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
