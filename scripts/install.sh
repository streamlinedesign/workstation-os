#!/bin/bash
# Turn a fresh Debian 13 install into the workstation. Idempotent; prints what it does.
# Run from the repo root as root:  sudo ./scripts/install.sh
set -eu
cd "$(dirname "$0")/.."
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }

say() { printf '\033[1m%s\033[0m\n' "$*"; }
put() {  # <src> <dst> [mode]
    install -D -m "${3:-0644}" "$1" "$2" && echo "  wrote $2"
}

say "1. Packages"
apt-get update -qq
apt-get install -y -qq \
    linux-image-rt-amd64 linux-headers-rt-amd64 \
    rt-tests stress-ng util-linux alsa-utils \
    build-essential cmake ninja-build git libasound2-dev \
    cage seatd                                 # kiosk Wayland compositor for the UI
echo "  installed"

say "2. User and groups"
id workstation >/dev/null 2>&1 || useradd -m -s /bin/bash -G audio,input,video,render workstation
usermod -aG audio,input "${SUDO_USER:-root}" 2>/dev/null || true
echo "  user 'workstation' in audio,input,video,render"

say "3. Kernel command line and GRUB"
put etc/default/grub.d/90-workstation.cfg /etc/default/grub.d/90-workstation.cfg
ROOT_UUID=$(findmnt -no UUID /)
sed "s/WSOS_ROOT_UUID/$ROOT_UUID/g" etc/grub.d/41_workstation_pc_mode > /etc/grub.d/41_workstation_pc_mode
chmod 0755 /etc/grub.d/41_workstation_pc_mode
echo "  wrote /etc/grub.d/41_workstation_pc_mode (root $ROOT_UUID)"
update-grub 2>&1 | sed 's/^/  /'

say "4. sysctl, limits, udev, modprobe"
put etc/sysctl.d/90-workstation.conf /etc/sysctl.d/90-workstation.conf
put etc/security/limits.d/90-workstation-audio.conf /etc/security/limits.d/90-workstation-audio.conf
put etc/udev/rules.d/90-workstation-audio.rules /etc/udev/rules.d/90-workstation-audio.rules
put etc/modprobe.d/90-workstation.conf /etc/modprobe.d/90-workstation.conf
[ -f /etc/workstation/core.conf ] || put etc/workstation/core.conf /etc/workstation/core.conf
sysctl -q --system >/dev/null
udevadm control --reload

say "5. Scripts and services"
put scripts/rtirq-prio.sh /usr/local/sbin/rtirq-prio.sh 0755
put scripts/rt-check.sh   /usr/local/sbin/rt-check.sh   0755
put scripts/boot-mode.sh  /usr/local/sbin/boot-mode.sh  0755
put systemd/instrument.target        /etc/systemd/system/instrument.target
put systemd/rtirq-prio.service       /etc/systemd/system/rtirq-prio.service
put systemd/workstation-core.service /etc/systemd/system/workstation-core.service
systemctl daemon-reload
systemctl enable rtirq-prio.service workstation-core.service >/dev/null 2>&1
echo "  enabled rtirq-prio.service workstation-core.service"

say "6. Desktop sound servers stay out of instrument mode"
# PipeWire and PulseAudio are fine in PC mode but must never grab the interface in
# instrument mode. They are user services; masking them for the 'workstation' user is enough.
sudo -u workstation XDG_RUNTIME_DIR=/run/user/$(id -u workstation) \
    systemctl --user mask pipewire pipewire-pulse wireplumber pulseaudio 2>/dev/null || true
echo "  masked pipewire/pulseaudio for user 'workstation'"

say "7. Default boot target"
if [ "${WSOS_DEFAULT_PC:-0}" = 1 ]; then
    systemctl set-default graphical.target
    echo "  default: PC mode (WSOS_DEFAULT_PC=1)"
else
    systemctl set-default instrument.target
    echo "  default: instrument mode (pick 'PC mode' in GRUB for the desktop)"
fi

cat <<EOF

Done. Next:
  1. Edit /etc/default/grub.d/90-workstation.cfg (WSOS_DSP_CPUS) for this CPU, then: update-grub
  2. Edit /etc/workstation/core.conf with the names from: wsc-devices
  3. Build and install workstation-core:  cmake -B build && cmake --build build && cmake --install build --prefix /usr/local
  4. reboot, then:  rt-check.sh 300
EOF
