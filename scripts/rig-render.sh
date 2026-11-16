#!/usr/bin/env bash
# Run Desk Transition inside an isolated real Omarchy shell, exercise both
# display scenes through live IPC, and capture the dedicated 16:9 output
# directly without cropping or image post-processing.
#
# The compositor on the rig is headless sway, not Hyprland. The shell and the
# helper run unchanged; hyprctl is tests/hyprctl-stub.sh, which answers the way
# Hyprland 0.57.2 (Lua config) does, so the helper must send the Lua forms and
# get "ok" back. A helper that regressed to the classic forms would hit that
# stub's real error replies, and this script would refuse the render.
set -euo pipefail

TARGET="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
OUT="${2:-$TARGET/preview.png}"
HOST="${OMARCHY_RIG_HOST:-intent-ops-buzz}"
CONTAINER="${OMARCHY_RIG_CONTAINER:-omarchy-rig}"
RES="${OMARCHY_RIG_RESOLUTION:-1280x720}"
SCALE="${OMARCHY_RIG_SCALE:-1.25}"
THEME="${OMARCHY_RIG_THEME:-tokyo-night}"
[[ "$THEME" =~ ^[a-z0-9-]+$ ]] || { echo "rig-render: unsafe theme name" >&2; exit 2; }
STUB_SRC="$(cd "$(dirname "$0")/.." && pwd)/tests/hyprctl-stub.sh"
[[ -f "$STUB_SRC" ]] || { echo "rig-render: tests/hyprctl-stub.sh is missing" >&2; exit 2; }
STUB_SHA="$(sha256sum "$STUB_SRC" | cut -d' ' -f1)"

for tool in jq identify convert; do
  command -v "$tool" >/dev/null 2>&1 || { echo "rig-render: $tool is required" >&2; exit 2; }
done
[[ -f "$TARGET/manifest.json" ]] || { echo "rig-render: no manifest.json" >&2; exit 2; }

MOD="$(jq -r '.id // empty' "$TARGET/manifest.json")"
[[ -n "$MOD" ]] || { echo "rig-render: manifest has no id" >&2; exit 2; }
NAME="${MOD##*.}"
RUN_ID="${NAME}-$$"

# List the files a fingerprint may cover, NUL-separated, as ./relative paths.
#
# At the root of a git work tree this is what git treats as part of the project:
# tracked files plus untracked files that are not ignored. A bare `find` also
# hashed ignored debris (nested node_modules, an ignored .beads Dolt store whose
# JSON carries the exec bit), so a receipt written from a developer clone did not
# describe the commit being submitted, and gates c37 and c43 (which list files
# this same way since contributing-clanker#82) rejected it. On a clean checkout
# both listings are identical, so existing receipts keep their fingerprint.
# Outside a git root it falls back to the plain walk. Needs GNU find 4.9+.
_fingerprint_candidates() {
  if [[ "$(git rev-parse --show-toplevel 2>/dev/null)" == "$(pwd -P)" ]]; then
    git ls-files -z --cached --others --exclude-standard 2>/dev/null | sed -z 's|^|./|'
  else
    find . -type f -not -path './.git/*' -print0 2>/dev/null
  fi
}

fingerprint() {
  ( cd "$TARGET" && _fingerprint_candidates \
 | find -files0-from - -maxdepth 0 -type f \
      -not -path './tests/*' -not -path './scripts/*' \
      -not -path './node_modules/*' -not -path './reports/*' -not -path './coverage/*' \
      \( -name '*.qml' -o -name '*.js' -o -name 'manifest.json' -o -perm -u+x \) \
      -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 cat 2>/dev/null \
      | sha256sum | cut -d' ' -f1 )
}

FP="$(fingerprint)"
SOURCE_COMMIT="$(git -C "$TARGET" rev-parse HEAD 2>/dev/null || printf unknown)"
SOURCE_DIRTY=false
if [[ "$SOURCE_COMMIT" == unknown ]] || \
   [[ -n "$(git -C "$TARGET" status --porcelain --untracked-files=all -- \
     '*.qml' '*.js' manifest.json bin preview.png README.md assets/banner.svg \
     scripts/rig-render.sh 2>/dev/null)" ]]; then
  SOURCE_DIRTY=true
fi

TGZ="$(mktemp -t desk-transition-render-XXXXXX.tgz)"
REMOTE="$(mktemp -t desk-transition-render-XXXXXX.sh)"
trap 'rm -f "$TGZ" "$REMOTE"' EXIT
tar czf "$TGZ" -C "$TARGET" --exclude=.git --exclude=tests --exclude=scripts \
  --exclude=node_modules --exclude=reports --exclude=coverage \
  --exclude=.rig-proof.json --exclude=.render-proof.json --exclude=preview.png \
  --exclude=render.png . || {
  echo "rig-render: could not package runtime tree" >&2; exit 2; }
ARCHIVE_SHA="$(sha256sum "$TGZ" | cut -d' ' -f1)"

echo "rig-render: shipping $NAME to $HOST/$CONTAINER"
scp -q -o BatchMode=yes "$TGZ" "$HOST:/tmp/rigrender-$RUN_ID.tgz" || {
  echo "rig-render: cannot reach $HOST" >&2; exit 2; }
scp -q -o BatchMode=yes "$STUB_SRC" "$HOST:/tmp/rigrender-$RUN_ID-hyprctl.sh" || {
  echo "rig-render: cannot ship the hyprctl stand-in" >&2; exit 2; }

# The rig's identity, read from the rig itself, so the receipt says what the
# render ran on rather than when it ran.
RIG_IDENTITY="$(ssh -o BatchMode=yes "$HOST" "docker exec -i $CONTAINER sh -s" 2>/dev/null <<'IDENT'
printf 'omarchy=%s\n' "$(git -C /root/omarchy rev-parse HEAD 2>/dev/null)"
printf 'qt6Base=%s\n' "$(pacman -Q qt6-base 2>/dev/null | cut -d' ' -f2)"
printf 'quickshell=%s\n' "$(pacman -Q quickshell 2>/dev/null | cut -d' ' -f2)"
printf 'hyprlandPackage=%s\n' "$(pacman -Q hyprland 2>/dev/null | cut -d' ' -f2)"
printf 'qmllint=%s\n' "$(/usr/lib/qt6/bin/qmllint --version 2>/dev/null | awk '{print $2}')"
IDENT
)" || RIG_IDENTITY=""
rig_field() { printf '%s\n' "$RIG_IDENTITY" | sed -n "s/^$1=//p" | head -n1; }
OMARCHY_COMMIT="$(rig_field omarchy)"; QT_BASE="$(rig_field qt6Base)"
QUICKSHELL_VERSION="$(rig_field quickshell)"; HYPRLAND_PACKAGE="$(rig_field hyprlandPackage)"
QMLLINT_VERSION="$(rig_field qmllint)"
[[ "$OMARCHY_COMMIT" =~ ^[0-9a-f]{40}$ && "$QT_BASE" =~ ^[0-9][0-9A-Za-z._-]*$ ]] || {
  echo "rig-render: could not read the rig's Omarchy commit and Qt version" >&2; exit 2; }

cat > "$REMOTE" <<REMOTE_EOF
#!/bin/sh
set -eu
MOD="$MOD"; NAME="$NAME"; RUN_ID="$RUN_ID"; RES="$RES"; SCALE="$SCALE"; THEME="$THEME"
RUNTIME=/tmp/desk-transition-runtime-\$RUN_ID
RIG_ROOT=/tmp/desk-transition-home-\$RUN_ID
RIG_BIN=/tmp/desk-transition-bin-\$RUN_ID
SWAY_CONFIG=/tmp/desk-transition-sway-\$RUN_ID.conf
SWAY_LOG=/tmp/desk-transition-sway-\$RUN_ID.log
QS_LOG=/tmp/desk-transition-qs-\$RUN_ID.log
ACTION_LOG=/tmp/desk-transition-actions-\$RUN_ID.log
MONITORS=/tmp/desk-transition-monitors-\$RUN_ID.json
RULES=/tmp/desk-transition-rules-\$RUN_ID.json
STUB=/tmp/rigrender-\$RUN_ID-hyprctl.sh
SHOT=/tmp/rigrender-\$RUN_ID.png
PLUGIN_DIR=\$RIG_ROOT/.config/omarchy/plugins/\$NAME
QS_PID=""; SWAY_PID=""
cleanup() {
  [ -z "\$QS_PID" ] || kill "\$QS_PID" 2>/dev/null || true
  [ -z "\$SWAY_PID" ] || kill "\$SWAY_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for path in "\$RUNTIME" "\$RIG_ROOT" "\$RIG_BIN"; do
  if [ -d "\$path" ]; then find "\$path" -depth -delete; fi
done
mkdir -p "\$RUNTIME" "\$PLUGIN_DIR" "\$RIG_BIN"
chmod 700 "\$RUNTIME" "\$RIG_ROOT" "\$RIG_ROOT/.config" \
  "\$RIG_ROOT/.config/omarchy" "\$RIG_ROOT/.config/omarchy/plugins" \
  "\$PLUGIN_DIR" "\$RIG_BIN"
tar xzf /tmp/rigrender-\$RUN_ID.tgz -C "\$PLUGIN_DIR"
# A real Omarchy install always has a current theme. Seed the state
# omarchy-theme-set writes (current/theme, theme.name, background) with the stock
# tokyo-night theme: current first-party shell plugins (image-picker, lock) read
# it from HOME/.local/state and log QML warnings when it is missing, which would
# otherwise read here as plugin warnings. OMARCHY_RIG_THEME picks another stock
# theme, to look at the panel on a light one; the committed preview is tokyo-night.
CURRENT="\$RIG_ROOT/.local/state/omarchy/current"
mkdir -p "\$CURRENT"
[ -d "/root/omarchy/themes/\$THEME" ] || { echo "rig-render: no theme \$THEME on the rig" >&2; exit 1; }
ln -nsf "/root/omarchy/themes/\$THEME" "\$CURRENT/theme"
printf '%s\n' "\$THEME" > "\$CURRENT/theme.name"
BACKGROUND=\$(ls "\$CURRENT/theme/backgrounds" | sort | head -n1)
ln -nsf "\$CURRENT/theme/backgrounds/\$BACKGROUND" "\$CURRENT/background"

# A docked HiDPI laptop: the desk monitor has the focus, so the Laptop scene has
# somewhere to move it. Fields are the ones hyprctl -j monitors all reports.
cat > "\$MONITORS" <<'JSON'
[
  {"name":"eDP-1","width":2880,"height":1800,"refreshRate":120.00000,"scale":2,"transform":0,"x":0,"y":0,"focused":false,"disabled":false,"mirrorOf":"none"},
  {"name":"DP-1","width":2560,"height":1440,"refreshRate":144.00000,"scale":1,"transform":0,"x":1440,"y":0,"focused":true,"disabled":false,"mirrorOf":"none"}
]
JSON
# The rules the user already has, which a position-only hl.monitor must merge into.
cat > "\$RULES" <<'JSON'
{"eDP-1":{"mode":"2880x1800@120","position":"0x0","scale":2},
 "DP-1":{"mode":"2560x1440@144","position":"1440x0","scale":1}}
JSON
: > "\$ACTION_LOG"
FIXTURE_SHA=\$(cat "\$MONITORS" "\$RULES" | sha256sum | awk '{print \$1}')

# The rig-only Hyprland boundary: tests/hyprctl-stub.sh, answering as Hyprland
# 0.57.2 with a Lua config. It records argv and merges hl.monitor rules the way
# Hyprland does. Production QML and the shipped helper execute unchanged.
STUB_SHA_REMOTE=\$(sha256sum "\$STUB" | awk '{print \$1}')
cp "\$STUB" "\$RIG_BIN/hyprctl"
chmod 700 "\$RIG_BIN/hyprctl"

cat > "\$RIG_ROOT/.config/omarchy/shell.json" <<JSON
{"version":1,"bar":{"position":"top","transparent":false,"centerAnchor":"omarchy.clock",
"layout":{"left":[{"id":"omarchy.workspaces"}],
"center":[{"id":"omarchy.clock","format":"dddd HH:mm"}],
"right":[{"id":"\$MOD"}]}},"plugins":[]}
JSON

cat > "\$SWAY_CONFIG" <<SWAY
output * resolution \$RES scale \$SCALE
seat * hide_cursor 1000
SWAY
export XDG_RUNTIME_DIR="\$RUNTIME"
WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
  sway --config "\$SWAY_CONFIG" >"\$SWAY_LOG" 2>&1 &
SWAY_PID=\$!
WAYLAND_SOCKET=""; attempt=0
while [ \$attempt -lt 30 ]; do
  WAYLAND_SOCKET=\$(find "\$RUNTIME" -maxdepth 1 -type s -name 'wayland-*' | head -1)
  [ -z "\$WAYLAND_SOCKET" ] || break
  attempt=\$((attempt + 1)); sleep 1
done
[ -n "\$WAYLAND_SOCKET" ] || { echo "rig-render: isolated Wayland socket did not start" >&2; exit 1; }
export WAYLAND_DISPLAY="\${WAYLAND_SOCKET##*/}"
export SWAYSOCK=\$(find "\$RUNTIME" -maxdepth 1 -type s -name 'sway-ipc.*.sock' | head -1)
[ -n "\$SWAYSOCK" ] || { echo "rig-render: isolated Sway IPC did not start" >&2; exit 1; }

export HOME="\$RIG_ROOT" OMARCHY_PATH=/root/omarchy
export PATH="\$RIG_BIN:\$PATH"
export HYPRCTL_LOG="\$ACTION_LOG" HYPRCTL_MONITORS="\$MONITORS" HYPRCTL_RULES="\$RULES" HYPRCTL_MODE=lua
qs -p /root/omarchy/shell >"\$QS_LOG" 2>&1 &
QS_PID=\$!

attempt=0
while [ \$attempt -lt 30 ]; do
  if grep -q '^-j monitors all\$' "\$ACTION_LOG" 2>/dev/null; then break; fi
  attempt=\$((attempt + 1)); sleep 1
done
[ \$attempt -lt 30 ] || { echo "rig-render: real panel did not scan the monitor fixture" >&2; tail -80 "\$QS_LOG" >&2; exit 1; }
[ -d "/proc/\$QS_PID" ] || { echo "rig-render: Quickshell exited before IPC" >&2; exit 1; }

qs -p /root/omarchy/shell ipc call "\$MOD" desk >/dev/null 2>&1
attempt=0
while [ \$attempt -lt 20 ]; do
  DESK_EVALS=\$(grep -c '^eval hl\.monitor(' "\$ACTION_LOG" 2>/dev/null || true)
  [ "\$DESK_EVALS" -ge 1 ] && break
  attempt=\$((attempt + 1)); sleep 1
done
sleep 1
DESK_EVALS=\$(grep -c '^eval hl\.monitor(' "\$ACTION_LOG" 2>/dev/null || true)
DESK_COUNT=\$(grep '^eval hl\.monitor(' "\$ACTION_LOG" 2>/dev/null | grep -o 'hl\.monitor(' | wc -l | tr -d ' ')
[ "\${DESK_EVALS:-0}" -eq 1 ] && [ "\${DESK_COUNT:-0}" -eq 2 ] || { echo "rig-render: Desk scene did not send one Lua eval placing two outputs" >&2; cat "\$ACTION_LOG" >&2; exit 1; }

qs -p /root/omarchy/shell ipc call "\$MOD" laptop >/dev/null 2>&1
attempt=0
while [ \$attempt -lt 20 ]; do
  LAPTOP_COUNT=\$(grep -Fxc 'dispatch hl.dsp.focus({ monitor = "eDP-1" })' "\$ACTION_LOG" 2>/dev/null || true)
  [ "\$LAPTOP_COUNT" -ge 1 ] && break
  attempt=\$((attempt + 1)); sleep 1
done
sleep 1
LAPTOP_COUNT=\$(grep -Fxc 'dispatch hl.dsp.focus({ monitor = "eDP-1" })' "\$ACTION_LOG" 2>/dev/null || true)
[ "\${LAPTOP_COUNT:-0}" -eq 1 ] || { echo "rig-render: Laptop scene did not focus the internal panel with the Lua form" >&2; cat "\$ACTION_LOG" >&2; exit 1; }
# Lua accepted every first attempt, so no classic fallback may have run.
CLASSIC_COUNT=\$(grep -Ec '^(keyword |dispatch focusmonitor )' "\$ACTION_LOG" 2>/dev/null || true)
[ "\$CLASSIC_COUNT" -eq 0 ] || { echo "rig-render: a classic hyprctl form ran on a Lua-configured Hyprland" >&2; cat "\$ACTION_LOG" >&2; exit 1; }
DISABLE_COUNT=\$(grep -ci 'disable' "\$ACTION_LOG" 2>/dev/null || true)
[ "\$DISABLE_COUNT" -eq 0 ] || { echo "rig-render: a scene attempted to disable an output" >&2; exit 1; }
# Position only: the layout moved and every output kept the mode and scale it had.
LAYOUT=\$(jq -c '{"eDP-1": .["eDP-1"].position, "DP-1": .["DP-1"].position}' "\$RULES")
RULES_KEPT=no
jq -e '.["eDP-1"].mode == "2880x1800@120" and .["eDP-1"].scale == 2 and .["DP-1"].mode == "2560x1440@144" and .["DP-1"].scale == 1' "\$RULES" >/dev/null 2>&1 && RULES_KEPT=yes
FOCUSED_OUT=\$(jq -r '[.[] | select(.focused) | .name] | join(",")' "\$MONITORS")

qs -p /root/omarchy/shell ipc call "\$MOD" toggle >/dev/null 2>&1
sleep 8
[ -d "/proc/\$QS_PID" ] || { echo "rig-render: Quickshell exited after IPC" >&2; exit 1; }

echo "===QML WARNINGS==="
grep -a -iE "(WARN|ERROR).*(qml|scene)|(qml|scene).*(WARN|ERROR)|cannot assign|is not a type|unable to|handler was registered|quickshell has crashed" "\$QS_LOG" \
  | grep -avE "libEGL|MESA|ZINK|failed to get driver|failed to create dri2" | head -20
grim "\$SHOT" 2>/dev/null

echo "===ACTION=== scenes-applied-panel-opened"
echo "===RUN=== \$RUN_ID"
echo "===LOGSHA=== \$(sha256sum "\$QS_LOG" | awk '{print \$1}')"
echo "===ACTIONLOGSHA=== \$(sha256sum "\$ACTION_LOG" | awk '{print \$1}')"
echo "===FIXTURESHA=== \$FIXTURE_SHA"
echo "===STUBSHA=== \$STUB_SHA_REMOTE"
echo "===DESKEVALS=== \$DESK_EVALS"
echo "===CLASSIC=== \$CLASSIC_COUNT"
echo "===LAYOUT=== \$LAYOUT"
echo "===RULESKEPT=== \$RULES_KEPT"
echo "===FOCUSED=== \$FOCUSED_OUT"
echo "===PACKAGE=== \$(sha256sum /tmp/rigrender-\$RUN_ID.tgz | awk '{print \$1}')"
echo "===DESK=== \$DESK_COUNT"
echo "===LAPTOP=== \$LAPTOP_COUNT"
echo "===DISABLE=== \$DISABLE_COUNT"
echo "===SHOT=== \$(ls -l "\$SHOT" | awk '{print \$5}') bytes"
REMOTE_EOF

scp -q -o BatchMode=yes "$REMOTE" "$HOST:/tmp/rigrender-$RUN_ID.sh" || exit 2
set +e
RESULT="$(ssh -o BatchMode=yes "$HOST" "docker cp /tmp/rigrender-$RUN_ID.tgz $CONTAINER:/tmp/ >/dev/null && \
  docker cp /tmp/rigrender-$RUN_ID-hyprctl.sh $CONTAINER:/tmp/ >/dev/null && \
  docker cp /tmp/rigrender-$RUN_ID.sh $CONTAINER:/tmp/ >/dev/null && \
  docker exec $CONTAINER sh /tmp/rigrender-$RUN_ID.sh" 2>&1)"
REMOTE_RC=$?
set -e
if [[ "$REMOTE_RC" -ne 0 ]]; then
  echo "rig-render: remote run failed (exit $REMOTE_RC)" >&2
  printf '%s\n' "$RESULT" >&2
  exit 1
fi

WARNINGS="$(printf '%s' "$RESULT" | sed -n '/===QML WARNINGS===/,/===ACTION===/p' | grep -vE '===' || true)"
SIZE="$(printf '%s' "$RESULT" | grep -oE '===SHOT=== [0-9]+' | grep -oE '[0-9]+' || true)"
REMOTE_SHA="$(printf '%s' "$RESULT" | grep -oE '===PACKAGE=== [a-f0-9]{64}' | awk '{print $2}' || true)"
RAW_LOG_SHA="$(printf '%s' "$RESULT" | grep -oE '===LOGSHA=== [a-f0-9]{64}' | awk '{print $2}' || true)"
ACTION_LOG_SHA="$(printf '%s' "$RESULT" | grep -oE '===ACTIONLOGSHA=== [a-f0-9]{64}' | awk '{print $2}' || true)"
FIXTURE_SHA="$(printf '%s' "$RESULT" | grep -oE '===FIXTURESHA=== [a-f0-9]{64}' | awk '{print $2}' || true)"
REMOTE_RUN_ID="$(printf '%s' "$RESULT" | grep -oE '===RUN=== [a-z0-9-]+' | awk '{print $2}' || true)"
ACTION="$(printf '%s' "$RESULT" | grep -oE '===ACTION=== [a-z0-9-]+' | awk '{print $2}' || true)"
DESK_COUNT="$(printf '%s' "$RESULT" | grep -oE '===DESK=== [0-9]+' | awk '{print $2}' || true)"
LAPTOP_COUNT="$(printf '%s' "$RESULT" | grep -oE '===LAPTOP=== [0-9]+' | awk '{print $2}' || true)"
DISABLE_COUNT="$(printf '%s' "$RESULT" | grep -oE '===DISABLE=== [0-9]+' | awk '{print $2}' || true)"
STUB_REMOTE_SHA="$(printf '%s' "$RESULT" | grep -oE '===STUBSHA=== [a-f0-9]{64}' | awk '{print $2}' || true)"
DESK_EVALS="$(printf '%s' "$RESULT" | grep -oE '===DESKEVALS=== [0-9]+' | awk '{print $2}' || true)"
CLASSIC_COUNT="$(printf '%s' "$RESULT" | grep -oE '===CLASSIC=== [0-9]+' | awk '{print $2}' || true)"
LAYOUT="$(printf '%s' "$RESULT" | sed -n 's/^===LAYOUT=== //p' | head -n1)"
RULES_KEPT="$(printf '%s' "$RESULT" | grep -oE '===RULESKEPT=== (yes|no)' | awk '{print $2}' || true)"
FOCUSED_OUT="$(printf '%s' "$RESULT" | grep -oE '===FOCUSED=== [A-Za-z0-9._,-]+' | awk '{print $2}' || true)"

if [[ -n "$WARNINGS" ]]; then
  echo "rig-render: plugin QML warnings:" >&2; printf '%s\n' "$WARNINGS" >&2
fi
if [[ -z "$SIZE" || "$SIZE" -lt 4000 ]]; then
  echo "rig-render: no usable screenshot came back" >&2; printf '%s\n' "$RESULT" >&2; exit 1
fi
[[ "$REMOTE_SHA" == "$ARCHIVE_SHA" ]] || { echo "rig-render: remote package hash mismatch" >&2; exit 1; }
[[ "$RAW_LOG_SHA" =~ ^[a-f0-9]{64}$ && "$ACTION_LOG_SHA" =~ ^[a-f0-9]{64}$ \
   && "$FIXTURE_SHA" =~ ^[a-f0-9]{64}$ && "$REMOTE_RUN_ID" == "$RUN_ID" ]] || {
  echo "rig-render: exact run/log provenance missing" >&2; exit 1; }
[[ "$ACTION" == scenes-applied-panel-opened && "$DESK_COUNT" == 2 && "$DESK_EVALS" == 1 \
   && "$LAPTOP_COUNT" == 1 && "$CLASSIC_COUNT" == 0 && "$DISABLE_COUNT" == 0 \
   && "$RULES_KEPT" == yes && "$FOCUSED_OUT" == eDP-1 \
   && "$LAYOUT" == '{"eDP-1":"0x0","DP-1":"1440x0"}' ]] || {
  echo "rig-render: live display-scene action proof missing" >&2; exit 1; }
[[ "$STUB_REMOTE_SHA" == "$STUB_SHA" ]] || { echo "rig-render: the hyprctl stand-in changed in transit" >&2; exit 1; }

ssh -o BatchMode=yes "$HOST" "docker cp $CONTAINER:/tmp/rigrender-$RUN_ID.png /tmp/rigrender-out-$RUN_ID.png >/dev/null" || exit 1
scp -q -o BatchMode=yes "$HOST:/tmp/rigrender-out-$RUN_ID.png" "$OUT" || exit 1

# Remove this run's per-run files from the rig; a leftover never fails a render.
RIG_LEFTOVERS="/tmp/desk-transition-runtime-$RUN_ID /tmp/desk-transition-home-$RUN_ID /tmp/desk-transition-bin-$RUN_ID \
  /tmp/desk-transition-sway-$RUN_ID.conf /tmp/desk-transition-sway-$RUN_ID.log /tmp/desk-transition-qs-$RUN_ID.log \
  /tmp/desk-transition-actions-$RUN_ID.log /tmp/desk-transition-monitors-$RUN_ID.json /tmp/desk-transition-rules-$RUN_ID.json \
  /tmp/rigrender-$RUN_ID.tgz /tmp/rigrender-$RUN_ID.sh /tmp/rigrender-$RUN_ID.png /tmp/rigrender-$RUN_ID-hyprctl.sh"
ssh -o BatchMode=yes "$HOST" "docker exec $CONTAINER rm -rf $RIG_LEFTOVERS >/dev/null 2>&1; \
  rm -f /tmp/rigrender-$RUN_ID.tgz /tmp/rigrender-$RUN_ID.sh /tmp/rigrender-$RUN_ID-hyprctl.sh /tmp/rigrender-out-$RUN_ID.png >/dev/null 2>&1" || true

DIMS="$(identify -format '%wx%h' "$OUT" 2>/dev/null || true)"
COVERAGE="$(convert "$OUT" -colorspace gray -threshold 3% -format '%[fx:mean]' info: 2>/dev/null || true)"
[[ "$DIMS" == 1280x720 ]] || { echo "rig-render: expected 1280x720, found $DIMS" >&2; exit 1; }
if [[ -z "$COVERAGE" ]] || ! awk -v coverage="$COVERAGE" 'BEGIN { exit !(coverage >= 0.35) }'; then
  echo "rig-render: nonblack coverage ${COVERAGE:-unreadable} is below 0.35" >&2; exit 1
fi
if [[ -n "$WARNINGS" ]]; then
  echo "rig-render: refusing receipt for warning-bearing shell log" >&2; exit 1
fi

PREVIEW_SHA="$(sha256sum "$OUT" | cut -d' ' -f1)"
jq -n --arg fp "$FP" --arg commit "$SOURCE_COMMIT" --argjson dirty "$SOURCE_DIRTY" \
  --arg archive "$ARCHIVE_SHA" --arg remote "$REMOTE_SHA" --arg rig "$HOST/$CONTAINER" \
  --arg run "$REMOTE_RUN_ID" --arg logSha "$RAW_LOG_SHA" --arg actionLogSha "$ACTION_LOG_SHA" \
  --arg fixtureSha "$FIXTURE_SHA" --arg sha "$PREVIEW_SHA" \
  --arg dimensions "${DIMS/x/ x }" --arg coverage "$COVERAGE" --arg scale "$SCALE" \
  --argjson desk "$DESK_COUNT" --argjson evals "$DESK_EVALS" --argjson laptop "$LAPTOP_COUNT" \
  --argjson classic "$CLASSIC_COUNT" --argjson disable "$DISABLE_COUNT" \
  --argjson layout "$LAYOUT" --arg focused "$FOCUSED_OUT" --arg stub "$STUB_SHA" --arg theme "$THEME" \
  --arg omarchy "$OMARCHY_COMMIT" --arg qt "$QT_BASE" --arg quickshell "$QUICKSHELL_VERSION" \
  --arg hyprland "$HYPRLAND_PACKAGE" --arg qmllint "$QMLLINT_VERSION" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{fingerprint:$fp,sourceCommit:$commit,sourceDirty:$dirty,
    sourcePackageSha256:$archive,remotePackageSha256:$remote,rig:$rig,runId:$run,
    rawShellLogSha256:$logSha,hyprlandActionLogSha256:$actionLogSha,fixtureSha256:$fixtureSha,
    packageBoundary:"repository shipment excluding receipts, tests, developer scripts, reports, and preview",
    evidenceBoundary:"isolated real Omarchy shell and unchanged QML/helper under a dedicated headless compositor (sway, not Hyprland); a stand-in hyprctl that models Hyprland 0.57.2 Lua-config replies over a deterministic two-output inventory; live IPC Desk and Laptop actions; direct full-frame grim capture with no crop or image post-processing",
    fixture:"rig-only two-output Hyprland inventory (HiDPI laptop panel plus 1440p monitor), per-output rules, and the tests/hyprctl-stub.sh argv recorder; no production fixture branch",
    hyprctlStubSha256:$stub,theme:$theme,
    rigIdentity:{omarchyCommit:$omarchy,qt6Base:$qt,quickshell:$quickshell,hyprlandPackage:$hyprland,qmllint:$qmllint},
    primaryAction:"live IPC applied both display scenes and opened the populated panel",
    storyEvidence:{monitorCount:2,deskCommands:$desk,deskEvals:$evals,laptopCommands:$laptop,classicCommands:$classic,disableCommands:$disable,focusedOutput:$focused,externalOutput:"DP-1",layout:$layout,rulesKept:true},
    outputScale:($scale|tonumber),visualInspection:{status:"pending",previewSha256:$sha,checks:[]},
    previewSha256:$sha,dimensions:$dimensions,nonblackCoverage:($coverage|tonumber),capturedAt:$at}' \
  > "$TARGET/.render-proof.json"

echo "rig-render: wrote $OUT ($DIMS, coverage $COVERAGE)"
echo "rig-render: both live display scenes and populated panel passed"
