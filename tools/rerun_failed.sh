#!/usr/bin/env bash
# File: tools/rerun_failed.sh
# Re-runs the failed tests of a regression log directory one at a time and says which are flaky and which are real
# (docs/qa/FLAKY_TESTS.md has the per-test rules).
#   usage: bash tools/rerun_failed.sh LOGDIR [RUNS]
# LOGDIR holds one <test>.log per test (and smoke.log), as the regression runner writes them. A test failed when its log
# has no "SUCCESS" line (smoke: no "ALL SCENES OK"); exit 139 after SUCCESS is the known crash on exit and is a pass.
# Each failed test is re-run alone up to RUNS times (default 2), stopping at the first pass:
#   FLAKY  passed on a re-run;
#   REAL   failed every re-run (look at the newest log under LOGDIR/rerun/).
# The perf gates (tests/test_*_perf.gd) are listed, not re-run: run them alone, on AC power, with no other Godot process.
# The re-run logs go to LOGDIR/rerun/<test>.<n>.log. Exit code: 1 if any test is REAL, else 0.
set -u
L="${1:?usage: bash tools/rerun_failed.sh LOGDIR [RUNS]}"
RUNS="${2:-2}"
cd "$(dirname "$0")/.." || exit 2
[ -d "$L" ] || { echo "no such log directory: $L"; exit 2; }
mkdir -p "$L/rerun"

passed() {   # $1 = log file, $2 = test name
	if [ "$2" = "smoke_all_stages" ]; then grep -q "ALL SCENES OK" "$1"; else grep -q "SUCCESS" "$1"; fi
}

others=$(tasklist 2>/dev/null | grep -ic "godot")
[ "${others:-0}" -gt 0 ] && echo "note: $others Godot process(es) already running; re-runs under load can still flake"

failed=()
perf=()
for f in "$L"/test_*.log "$L"/smoke.log; do
	[ -f "$f" ] || continue
	t=$(basename "$f" .log)
	[ "$t" = "smoke" ] && t="smoke_all_stages"
	[ -f "tests/$t.gd" ] || continue
	passed "$f" "$t" && continue
	case "$t" in
		*_perf) perf+=("$t") ;;
		*) failed+=("$t") ;;
	esac
done

if [ ${#failed[@]} -eq 0 ] && [ ${#perf[@]} -eq 0 ]; then
	echo "no failed tests in $L"
	exit 0
fi

real=0
for t in "${failed[@]}"; do
	verdict="REAL"
	for n in $(seq 1 "$RUNS"); do
		log="$L/rerun/$t.$n.log"
		godot --headless --path . --script "tests/$t.gd" > "$log" 2>&1
		rc=$?
		if passed "$log" "$t"; then
			verdict="FLAKY"
			[ $rc -eq 139 ] && rc="0(139)"
			break
		fi
	done
	[ "$verdict" = "REAL" ] && real=1
	echo "$verdict $t (re-run $n of $RUNS, exit=$rc) :: $(grep -E 'SUCCESS|FAIL|ALL SCENES OK' "$log" | tail -1 | cut -c1-120)"
done

for t in "${perf[@]}"; do
	echo "PERF  $t: not re-run; run it alone on AC power: godot --headless --path . --script tests/$t.gd"
done
pw=$(powershell.exe -NoProfile -Command "(Get-CimInstance -Namespace root/wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue).PowerOnline" 2>/dev/null | tr -d '\r')
[ ${#perf[@]} -gt 0 ] && echo "power: PowerOnline=${pw:-unknown (no battery reported)}"
exit $real
