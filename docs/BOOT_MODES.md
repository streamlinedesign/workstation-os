# Boot modes

One installation, two ways to come up. Both share the kernel, the packages and the home
directories; only the systemd target differs.

## Instrument mode (default)

`instrument.target` pulls in `multi-user.target` (network, udev, logging) plus
`rtirq-prio.service` and `workstation-core.service`. No display manager, no desktop
session, no PipeWire or PulseAudio. From Stage 4 the UI runs here too, as a single
fullscreen app on `cage`, a kiosk Wayland compositor: no window manager, no decorations,
nothing that can steal focus or the sound card.

A TTY is still there (`Ctrl+Alt+F2`) for maintenance, and `ssh` works if enabled.

## PC mode

The GRUB entry "Workstation: PC mode (desktop)" boots the same root with
`systemd.unit=graphical.target`, which starts whatever desktop is installed. PipeWire
runs normally, so browsers, DAWs and video calls behave like any Debian desktop.
Nothing from instrument mode is running, so there is no fight over the audio interface.

## Switching without a reboot

```
sudo boot-mode.sh pc            # stop the instrument, start the desktop
sudo boot-mode.sh instrument    # the other way
sudo boot-mode.sh default pc    # change what the machine boots into
```

`systemctl isolate` stops every unit not wanted by the new target, so the audio core
is down before the desktop sound server starts, and the other way round.

## Why not one user per mode

A separate user is not needed and would split the sample library and projects. The
`workstation` user owns the audio core service; your own account logs into PC mode
and is in the `audio` group, so it can run `wsc-play` by hand for testing.
