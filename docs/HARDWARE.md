# Reference hardware

Decision: develop on one reference machine first, widen later. For now the reference
machine is the development laptop (NVMe, 8 GB, 16 GB planned). Fill in the table as the
parts are confirmed so `90-workstation.cfg` and `core.conf` can be checked against it.

| Part | Model | Notes |
| --- | --- | --- |
| CPU | [MODEL] | core count decides `WSOS_DSP_CPUS` |
| RAM | 8 GB | 16 GB is the cheapest quality upgrade |
| Storage | NVMe | sample streaming needs it |
| Audio interface | [MODEL] | class-compliant USB 2 is the safest choice on Linux |
| MIDI | Akai MPK mini + [KEYBOARD] | USB MIDI, class compliant |
| Display | [MODEL] | touch is optional; the UI is keyboard and mouse first |

## Choosing an audio interface

Class-compliant USB interfaces (Focusrite Scarlett, MOTU M-series, RME Babyface Pro
via class mode, Behringer UMC) need no driver and work with `snd-usb-audio` at 64
frames. Avoid anything that needs a vendor driver on Linux. PCIe cards (RME HDSPe) are
the lowest-latency option if the machine is a desktop.

## BIOS settings that matter

- Disable C-states deeper than C1, or set the "performance" power profile.
- Disable Intel SpeedStep / AMD Cool'n'Quiet if the governor cannot hold the frequency.
- Disable USB legacy support: it causes SMIs that no kernel setting can prevent.
- Disable the onboard sound card if an external interface is used, so it never becomes `hw:0`.
