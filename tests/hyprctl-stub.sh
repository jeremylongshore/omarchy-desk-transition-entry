#!/bin/sh
# A stand-in for hyprctl that answers the way a real Hyprland answers, in both
# configuration worlds, so the helper's argv, success test and fallback order are
# exercised against the real replies rather than against an exit-0 stub.
#
# HYPRCTL_MODE=lua (default) models Hyprland 0.57.2, the Lua-configured release
# (hyprwm/Hyprland tag v0.57.2, 11cbc6c577b8). The config manager type has no
# hyprlang member there (src/config/ConfigManager.hpp:28):
#   hyprctl dispatch X   runs `return hl.dispatch(X)`      src/ipc/s1/Commands.cpp:1332-1346
#   a Lua miss           prints "warning: ..." and exits 0  LuaBindingsDispatchers.cpp:1086-1089
#                                                           (WARN level), LuaBindingsInternal.cpp:356-365,
#                                                           ConfigManager.cpp:907-913, ConfigErrors.hpp:44
#   a syntax error       prints "error: 3 ..." and exits 7  ConfigManager.cpp:867-873, hyprctl/src/main.cpp:285
#   hyprctl eval X       runs X, prints "ok"                Commands.cpp:1316-1330
#   hyprctl keyword      is not registered: "unknown request", exit 0
#                                                           Commands.cpp:2121-2126, S1.cpp:107
#   hl.monitor({...})    starts from the existing rule NAMED THE SAME and changes only the
#                        fields given; with no same-named rule it starts from the defaults
#                        (preferred mode, automatic scale, 60 Hz)
#                                                           LuaBindingsConfigRules.cpp:1098-1100, 1134,
#                                                           MonitorRuleManager.cpp:36-37,
#                                                           MonitorRule.hpp:43-46
# HYPRCTL_MODE=classic models Hyprland 0.54.3, the last release configured with
# hyprlang (hyprwm/Hyprland tag v0.54.3, 521ece463c4a):
#   hyprctl eval         does not exist: "unknown request", exit 0   src/debug/HyprCtl.cpp:2177
#   hyprctl dispatch hl.dsp.focus({ ...   "Invalid dispatcher", exit 0   HyprCtl.cpp:1235-1247
#   hyprctl dispatch focusmonitor N       "ok", found or not      HyprCtl.cpp:1253, KeybindManager.cpp:1724
#   hyprctl keyword monitor ...           replaces the WHOLE rule, then "ok"
#                                                           HyprCtl.cpp:1256-1345, ConfigManager.cpp:2393
#
# HYPRCTL_EVAL_FAIL=1 makes `eval` fail with a Lua runtime error, as a bad rule would.
#
# HYPRCTL_GONE is a space-separated list of outputs the compositor still lists in
# `monitors` but no longer finds at dispatch time (an output unplugged between the
# helper's read and its dispatch).
set -u
printf '%s\n' "$*" >> "$HYPRCTL_LOG"
mode="${HYPRCTL_MODE:-lua}"

if [ "${1:-}" = "-j" ] && [ "${2:-}" = "monitors" ]; then
  cat "$HYPRCTL_MONITORS"
  exit 0
fi

cmd="${1:-}"
[ "$#" -gt 0 ] && shift
arg="$*"

known() {
  case " ${HYPRCTL_GONE:-} " in *" $1 "*) return 1 ;; esac
  jq -e --arg n "$1" 'any(.[]; .name == $n)' "$HYPRCTL_MONITORS" >/dev/null
}

focus_monitor() {
  tmp="$HYPRCTL_MONITORS.tmp"
  jq --arg n "$1" 'map(.focused = (.name == $n))' "$HYPRCTL_MONITORS" > "$tmp" && mv "$tmp" "$HYPRCTL_MONITORS"
}

reply() {
  printf '%s\n' "$1"
  case "$1" in "error:"*) exit 7 ;; esac
  exit 0
}

# rules.json maps an output name to its rule: {mode, position, scale, transform}.
rule_merge() { # name field-json
  tmp="$HYPRCTL_RULES.tmp"
  jq --arg n "$1" --argjson f "$2" '.[$n] = ((.[$n] // {mode: "preferred", scale: "auto"}) + $f)' "$HYPRCTL_RULES" > "$tmp" && mv "$tmp" "$HYPRCTL_RULES"
}

rule_replace() { # name rule-json
  tmp="$HYPRCTL_RULES.tmp"
  jq --arg n "$1" --argjson r "$2" '.[$n] = $r' "$HYPRCTL_RULES" > "$tmp" && mv "$tmp" "$HYPRCTL_RULES"
}

if [ "$mode" = "lua" ]; then
  case "$cmd" in
    eval)
      if [ -n "${HYPRCTL_EVAL_FAIL:-}" ]; then
        reply "error: [string \"$arg\"]:1: hl.monitor: field 'position': invalid offset"
      fi
      statements="$(printf '%s' "$arg" | grep -oE 'hl\.monitor\(\{ [^}]*\}\)')"
      stripped="$(printf '%s' "$statements" | tr -d '\n ')"
      squeezed="$(printf '%s' "$arg" | tr -d ' ')"
      if [ -z "$statements" ] || [ "$stripped" != "$squeezed" ]; then
        reply "error: 3 [string \"$arg\"]:1: syntax error near '$(printf '%s' "$arg" | cut -c1-12)'"
      fi
      # Merge exactly the fields a statement names, so a statement that also names
      # mode or scale shows up as a changed rule.
      printf '%s\n' "$statements" | while IFS= read -r statement; do
        out="$(printf '%s' "$statement" | sed -n 's/.*output = "\([^"]*\)".*/\1/p')"
        pos="$(printf '%s' "$statement" | sed -n 's/.*position = "\([^"]*\)".*/\1/p')"
        mod="$(printf '%s' "$statement" | sed -n 's/.*mode = "\([^"]*\)".*/\1/p')"
        scl="$(printf '%s' "$statement" | sed -n 's/.*scale = \([0-9.]*\).*/\1/p')"
        if [ -n "$out" ] && [ -n "$pos" ]; then
          rule_merge "$out" "$(jq -cn --arg p "$pos" --arg m "$mod" --arg s "$scl" \
            '{position: $p} + (if $m != "" then {mode: $m} else {} end) + (if $s != "" then {scale: ($s | tonumber)} else {} end)')"
        fi
      done
      reply ok
      ;;
    dispatch)
      case "$arg" in
        'hl.dsp.focus({ monitor = "'*'" })')
          name="${arg#*monitor = \"}"
          name="${name%\" \})}"
          if known "$name"; then focus_monitor "$name"; reply ok; fi
          reply "warning: [string \"return hl.dispatch($arg)\"]:1: hl.focus.monitor: monitor not found"
          ;;
        *"("*) reply "error: 3 [string \"return hl.dispatch($arg)\"]:1: attempt to call a nil value" ;;
        *)
          near="$(printf '%s' "${arg#* }" | sed 's/[^A-Za-z0-9_].*//')"
          reply "error: 3 [string \"return hl.dispatch($arg)\"]:1: ')' expected near '$near'

 → Note: dispatch in lua is a shorthand for hl.dispatch(...), your syntax might need to be updated."
          ;;
      esac
      ;;
    *) reply "unknown request" ;;
  esac
fi

# Classic (hyprlang) Hyprland.
case "$cmd" in
  dispatch)
    case "$arg" in
      "focusmonitor "*)
        name="${arg#focusmonitor }"
        # The classic focusmonitor dispatcher reports success even when no monitor matches.
        known "$name" && focus_monitor "$name"
        reply ok
        ;;
      *) reply "Invalid dispatcher" ;;
    esac
    ;;
  keyword)
    case "$arg" in
      "monitor "*)
        spec="${arg#monitor }"
        name="$(printf '%s' "$spec" | cut -d, -f1)"
        rule_replace "$name" "$(printf '%s' "$spec" | jq -R -c 'split(",") | {mode: .[1], position: .[2], scale: .[3], transform: (if .[4] == "transform" then .[5] else "0" end)}')"
        reply ok
        ;;
      *) reply "Invalid input: command and value not properly formatted" ;;
    esac
    ;;
  *) reply "unknown request" ;;
esac
