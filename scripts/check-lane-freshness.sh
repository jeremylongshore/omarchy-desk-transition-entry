#!/usr/bin/env bash
# Compare the vendored gate lane against canonical upstream, not just against
# its own manifest. A shallow clone prevents downloader-to-shell patterns while
# keeping the network boundary explicit and deterministic.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
GATES="$HERE/gates"
MANIFEST="$GATES/.lane-manifest"
REPO="${LANE_CANONICAL_REPO:-jeremylongshore/contributing-clanker}"
BRANCH="${LANE_CANONICAL_BRANCH:-master}"
REMOTE="https://github.com/$REPO.git"

[[ -f "$MANIFEST" ]] || { echo "check-lane-freshness: no .lane-manifest; run scripts/sync-gate-lane.sh" >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "check-lane-freshness: git is required" >&2; exit 1; }

RECORDED=$(/usr/bin/grep -m1 '^# canonical:' "$MANIFEST" | /usr/bin/sed 's/.*@//')
echo "vendored lane recorded from: ${RECORDED:-unknown}"
echo "comparing against $REPO@$BRANCH"

behind=0
checked=0
FETCH_ROOT="$(mktemp -d -t omarchy-gate-freshness.XXXXXXXX)"
trap 'rm -rf -- "$FETCH_ROOT"' EXIT
CANON_REPO="$FETCH_ROOT/canonical"

if ! /usr/bin/git clone --quiet --depth 1 --branch "$BRANCH" "$REMOTE" "$CANON_REPO"; then
  echo "check-lane-freshness: canonical clone was unreachable - treating as inconclusive, not stale" >&2
  exit 0
fi
CANON_GATES="$CANON_REPO/skills/contribute/scripts/gates"
CURRENT=$(/usr/bin/git -C "$CANON_REPO" rev-parse HEAD 2>/dev/null || echo unknown)
echo "canonical source currently at: $CURRENT"

while read -r want file; do
  [[ "$want" == \#* || -z "$want" ]] && continue
  canonical="$CANON_GATES/$file"
  if [[ ! -f "$canonical" ]]; then
    echo "  ✗  $file - absent from canonical"
    behind=1
    continue
  fi
  checked=$((checked + 1))
  got=$(/usr/bin/sha256sum "$canonical" | /usr/bin/cut -d' ' -f1)
  local_hash=$(cd "$GATES" && /usr/bin/sha256sum "$file" | /usr/bin/cut -d' ' -f1)
  if [[ "$got" != "$local_hash" ]]; then
    echo "  ✗  $file - differs from canonical"
    behind=1
  fi
done < "$MANIFEST"

if [[ "$behind" -ne 0 ]]; then
  echo
  echo "check-lane-freshness: VENDORED LANE DOES NOT MATCH CANONICAL." >&2
  echo "  A stale gate does not fail, it reports green. Re-sync before trusting this lane:" >&2
  echo "    scripts/sync-gate-lane.sh && scripts/run-plugin-gates.sh" >&2
  exit 1
fi

echo "check-lane-freshness: in sync with canonical ($checked files compared)"
exit 0
