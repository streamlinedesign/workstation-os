#!/bin/bash
# Switch between instrument mode and PC mode without rebooting, or set the default.
#
#   boot-mode.sh instrument        switch now
#   boot-mode.sh pc                switch now
#   boot-mode.sh default <mode>    set what the machine boots into
set -eu
case "${1:-}" in
    instrument) systemctl isolate instrument.target ;;
    pc)         systemctl isolate graphical.target ;;
    default)
        case "${2:-}" in
            instrument) systemctl set-default instrument.target ;;
            pc)         systemctl set-default graphical.target ;;
            *) echo "usage: $0 default instrument|pc"; exit 2 ;;
        esac ;;
    *) echo "usage: $0 instrument|pc|default <mode>"; exit 2 ;;
esac
