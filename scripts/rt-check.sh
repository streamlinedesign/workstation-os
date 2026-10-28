#!/bin/bash
# Stage 0 exit test: scheduling latency on the DSP cores while the rest of the machine
# is hammered. Pass = worst case under 100 µs. Run as root after a reboot.
#
#   sudo ./scripts/rt-check.sh [seconds, default 300]
set -u
DURATION="${1:-300}"
LIMIT_US=100

for tool in cyclictest stress-ng; do
    command -v "$tool" >/dev/null || { echo "missing $tool: apt install rt-tests stress-ng"; exit 2; }
done

DSP_CPUS=$(grep -o 'isolcpus=[^ ]*' /proc/cmdline | sed -e 's/isolcpus=//' -e 's/[a-z_][a-z_]*,//g')
echo "kernel:    $(uname -r)"
echo "preempt:   $(grep -o 'PREEMPT_RT\|PREEMPT' /proc/version | head -1 || echo none)"
echo "cmdline:   $(cat /proc/cmdline)"
echo "dsp cores: ${DSP_CPUS:-none (isolcpus not set, testing all cores)}"
echo "governor:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
echo "duration:  ${DURATION}s, pass if max < ${LIMIT_US} µs"
echo

# Load: CPU, memory, disk and interrupts on the housekeeping cores.
stress-ng --cpu 0 --vm 2 --vm-bytes 512M --io 2 --hdd 1 --timeout "${DURATION}s" --quiet &
STRESS=$!
sleep 2

if [ -n "$DSP_CPUS" ]; then
    AFF="-a $DSP_CPUS"
else
    AFF=""
fi
# One measuring thread per DSP core at priority 80 (between IRQ thread 90 and core 70),
# 1 ms interval, histogram to a file for the record.
LOG="/var/log/workstation-rt-check-$(date +%Y%m%d-%H%M%S).log"
# shellcheck disable=SC2086
cyclictest $AFF -t -p 80 -i 1000 -m -N -D "${DURATION}" -h 400 -q > "$LOG" 2>&1
kill "$STRESS" 2>/dev/null; wait "$STRESS" 2>/dev/null

MAX_NS=$(grep -E '^# Max Latencies' "$LOG" | tr -s ' ' | cut -d: -f2 | tr ' ' '\n' | sort -n | tail -1)
MAX_US=$(( ${MAX_NS:-0} / 1000 ))
grep -E '^# (Min|Avg|Max) Latencies' "$LOG"
echo
echo "worst case: ${MAX_US} µs   (full histogram in $LOG)"
if [ "$MAX_US" -lt "$LIMIT_US" ]; then
    echo "PASS: under ${LIMIT_US} µs. Ready for the 24-hour wsc-play soak."
    exit 0
fi
echo "FAIL: over ${LIMIT_US} µs. Usual causes: not on the rt kernel, C-states still enabled,"
echo "      governor not 'performance', SMI storms (check BIOS: disable USB legacy, thermal throttling), or a GPU driver."
exit 1
