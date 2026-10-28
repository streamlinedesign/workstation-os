#!/bin/bash
# Raise the kernel IRQ threads that carry audio to SCHED_FIFO above the audio core,
# and push everything else down. With `threadirqs` every IRQ handler is a thread named
# irq/<n>-<name>, so this is just chrt on the right PIDs.
#
# Priorities (SCHED_FIFO 1..99):
#   90  sound card / USB host controller that carries the audio interface
#   85  other USB host controllers (MIDI controllers live here)
#   70  the audio core thread (set by workstation-core itself)
#   50  everything else that was already RT (default for irq threads)
set -u

AUDIO_PRIO=90
USB_PRIO=85
DSP_CPUS="${WSOS_DSP_CPUS:-$(grep -o 'isolcpus=[^ ]*' /proc/cmdline | sed -e 's/isolcpus=//' -e 's/[a-z_][a-z_]*,//g')}"

set_prio() {  # <pattern> <priority>
    for pid in $(pgrep -f "irq/[0-9]+-$1"); do
        chrt -f -p "$2" "$pid" 2>/dev/null && echo "irq thread $pid ($(tr -d '\0' < /proc/$pid/comm)) -> FIFO $2"
        # Move the audio IRQ thread onto the isolated cores next to the audio core.
        [ -n "$DSP_CPUS" ] && [ "$2" = "$AUDIO_PRIO" ] && taskset -cp "$DSP_CPUS" "$pid" >/dev/null 2>&1
    done
}

# Sound cards: snd_hda_intel, snd_usb_audio appear in the IRQ name via their PCI/USB parent.
set_prio 'snd'      "$AUDIO_PRIO"
set_prio 'xhci_hcd' "$USB_PRIO"   # USB 3 controllers (USB audio and MIDI)
set_prio 'ehci_hcd' "$USB_PRIO"
set_prio 'ohci_hcd' "$USB_PRIO"

# If the audio interface is USB, the xhci controller it hangs off is the one that matters.
# Find it from the sound card's sysfs path and promote only that controller.
for card in /sys/class/sound/card*; do
    dev=$(readlink -f "$card/device" 2>/dev/null) || continue
    case "$dev" in *usb*)
        irq=$(cat "$(echo "$dev" | sed 's#\(/sys/devices/pci[^/]*/[^/]*\)/.*#\1#')/irq" 2>/dev/null) || continue
        for pid in $(pgrep -f "irq/${irq}-"); do
            chrt -f -p "$AUDIO_PRIO" "$pid" 2>/dev/null && echo "usb audio host irq $irq ($pid) -> FIFO $AUDIO_PRIO"
            [ -n "$DSP_CPUS" ] && taskset -cp "$DSP_CPUS" "$pid" >/dev/null 2>&1
        done ;;
    esac
done

# Performance governor on every core: frequency changes are latency spikes.
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$g" ] && echo performance > "$g"
done
exit 0
