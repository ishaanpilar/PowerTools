#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 PowerTools AI contributors

# Samples the Developer build's own CPU and memory to check Health Coach
# against the budgets in docs/ai-health-coach/README.md section 6:
#   - Installed, AI mode Off: no added idle CPU, at most +2 MB.
#   - Installed, On demand, idle: the same.
#   - Per explanation: app memory at most +15 MB, app CPU at most 0.2 s.
#
# Automates only what needs no click or keystroke: reading `ps`, and
# toggling Health Coach's own install/mode defaults directly (never
# simulated UI input, unlike Tools/ui-smoke.sh - a deliberate difference,
# not an oversight: this script's own AI text-actions session found live
# Accessibility-driven interaction with a real AI call landing keystrokes
# somewhere unintended, so the one step that cannot be done without
# actually pressing Explain is left to the operator, prompted for by name).
#
# Usage: ./Tools/measure-health-coach-budget.sh
# Requires the Developer build installed (./build.sh --dev --install) and
# already running.
set -uo pipefail

APP="/Applications/PowerTools (Developer).app"
PROCESS="PowerToolsDeveloper"
IDLE_SAMPLE_SECONDS=15
SAMPLE_INTERVAL=1
DEFAULTS_DOMAIN="com.powertools.utils.dev"

if [[ ! -d "$APP" ]]; then
    echo "✗ $APP not installed — run ./build.sh --dev --install first" >&2
    exit 1
fi
if ! pgrep -xq "$PROCESS"; then
    echo "✗ $PROCESS is not running — launch it first" >&2
    exit 1
fi
PID=$(pgrep -x "$PROCESS" | head -1)

sample() {
    # %cpu is an average since process start, not instantaneous - two
    # samples far enough apart approximate the rate over that window.
    ps -o %cpu=,rss= -p "$PID" 2>/dev/null
}

average_over() {
    local seconds=$1
    local count=0 cpu_sum=0 rss_sum=0
    local elapsed=0
    while (( elapsed < seconds )); do
        local reading
        reading=$(sample) || break
        local cpu rss
        cpu=$(echo "$reading" | awk '{print $1}')
        rss=$(echo "$reading" | awk '{print $2}')
        cpu_sum=$(echo "$cpu_sum + $cpu" | bc)
        rss_sum=$((rss_sum + rss))
        count=$((count + 1))
        sleep "$SAMPLE_INTERVAL"
        elapsed=$((elapsed + SAMPLE_INTERVAL))
    done
    if (( count == 0 )); then
        echo "0 0"
        return
    fi
    echo "$(echo "scale=2; $cpu_sum / $count" | bc) $((rss_sum / count))"
}

echo "▸ Sampling $PROCESS (pid $PID) for ${IDLE_SAMPLE_SECONDS}s with Health Coach as currently configured…"
read -r BASELINE_CPU BASELINE_RSS_KB < <(average_over "$IDLE_SAMPLE_SECONDS")
echo "  baseline: ${BASELINE_CPU}% CPU, $((BASELINE_RSS_KB / 1024)) MB RSS"

echo ""
echo "▸ This script only flips defaults directly (no simulated clicks)."
echo "  To measure the +2 MB/no-idle-CPU budget for installing Health Coach,"
echo "  quit the app, run:"
echo "    defaults delete $DEFAULTS_DOMAIN featureAvailable.healthCoach 2>/dev/null; true"
echo "  relaunch, let it settle for 30s, then run this script again and"
echo "  compare against the baseline above."

echo ""
echo "▸ Per-explanation budget (app memory at most +15 MB, CPU at most 0.2s of"
echo "  process time, first words on device within 1s, cancel within 100ms)"
echo "  needs a real Explain press, which this script will not simulate."
echo "  With Health Coach showing a finding and the panel open:"
echo "    1. Note the RSS above as your 'before' figure."
echo "    2. Press Explain yourself, time to first word by eye or a stopwatch."
echo "    3. Immediately after it finishes, run:"
echo "         ps -o rss= -p $PID"
echo "       and compare against the 'before' RSS - the difference should be"
echo "       under 15 MB (15,360 KB)."
echo "    4. Press Explain again and press Cancel immediately; it should stop"
echo "       within about 100ms - by eye, effectively instant."
