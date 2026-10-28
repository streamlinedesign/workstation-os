# workstation-os

The operating system side of the synthesizer workstation: a Debian 13 (trixie) system
tuned to run `workstation-core` with no xruns at 64-frame periods. Working name; the real
name is still open.

This repo holds configuration, not code: kernel command line, real-time limits, IRQ
priorities, the systemd service that boots straight into the instrument, and the
scripts that prove the tuning works. Stage 0 and the kernel half of Stage 1 live here.

## What a tuned machine looks like

| Layer | Setting | Why |
| --- | --- | --- |
| Kernel | `linux-image-rt-amd64` (PREEMPT_RT, mainline since 6.12) | Bounded scheduling latency |
| Boot | `threadirqs isolcpus=… nohz_full=… rcu_nocbs=…` | Audio IRQ and thread get their own cores, no timer ticks |
| Power | `processor.max_cstate=1 intel_idle.max_cstate=0`, performance governor | Deep sleep states cost 100+ µs to wake |
| Limits | `rtprio 95`, `memlock unlimited` for the `audio` group | SCHED_FIFO and mlockall without root |
| IRQs | audio interface IRQ thread at priority 90, above the audio thread at 70 | The driver must run before the engine |
| Boot target | `workstation-core.service` in `instrument.target` | No desktop in the audio path |

## Install on a fresh Debian 13

```
git clone https://github.com/streamlinedesign/workstation-os
cd workstation-os
sudo ./scripts/install.sh        # packages, configs, GRUB, limits, service
sudo reboot
sudo ./scripts/rt-check.sh 300   # 5-minute cyclictest under load; Stage 0 exit test
```

`install.sh` is idempotent and prints every file it writes. Everything it installs is
in `etc/` and `systemd/` in this repo, so you can read it before running it.

## Two ways to boot

- **Instrument mode** (default): boots into `instrument.target`, which starts the audio
  core and, later, the UI on a kiosk compositor. No desktop, no PipeWire.
- **PC mode**: a second GRUB entry boots the same system into `graphical.target` with a
  normal desktop for browsing, DAW work or maintenance. See `docs/BOOT_MODES.md`.

## Exit tests

- **Stage 0:** `rt-check.sh` worst-case latency under 100 µs with the machine loaded.
- **Stage 1:** `wsc-play` at 64 frames, 24 hours, `xruns` stays 0.

## Layout

```
etc/        files installed under /etc (GRUB, sysctl, limits, udev, modprobe)
systemd/    units and targets
scripts/    install.sh, rt-check.sh, rtirq-prio.sh, boot-mode.sh
docs/       boot modes, hardware notes, tuning rationale
```
