#!/bin/bash
# Installs t2fancurve and enables it at boot.
# With --prochot, also installs t2prochot (only for Macs without a working battery).
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./install.sh [--prochot]"; exit 1; }
cd "$(dirname "$0")"

PROCHOT=0
[ "$1" = "--prochot" ] && PROCHOT=1
STEPS=5; [ "$PROCHOT" -eq 1 ] && STEPS=6

echo "[1/$STEPS] Installing /usr/local/bin/t2fancurve"
install -Dm755 t2fancurve /usr/local/bin/t2fancurve

echo "[2/$STEPS] Installing /etc/t2fancurve.conf"
if [ -e /etc/t2fancurve.conf ]; then
    echo "      Existing config kept"
else
    install -Dm644 t2fancurve.conf /etc/t2fancurve.conf
fi

echo "[3/$STEPS] Enabling fan control in the macsmc-hwmon driver"
echo "options macsmc-hwmon fan_control=1" > /etc/modprobe.d/macsmc-hwmon.conf

echo "[4/$STEPS] Disabling t2fanrd if present"
if systemctl is-enabled t2fanrd >/dev/null 2>&1; then
    systemctl disable --now t2fanrd
    echo "      t2fanrd disabled"
else
    echo "      Not installed or already disabled"
fi

echo "[5/$STEPS] Installing and enabling the fan service"
install -Dm644 t2fancurve.service /etc/systemd/system/t2fancurve.service
systemctl daemon-reload
systemctl enable t2fancurve

if [ "$PROCHOT" -eq 1 ]; then
    echo "[6/$STEPS] Installing t2prochot"
    command -v wrmsr >/dev/null || { echo "      msr-tools is not installed - install it and run this again"; exit 1; }
    install -Dm755 t2prochot /usr/local/bin/t2prochot
    install -Dm644 t2prochot.service /etc/systemd/system/t2prochot.service
    install -Dm755 t2prochot-sleep /usr/lib/systemd/system-sleep/t2prochot
    systemctl daemon-reload
    systemctl enable t2prochot
    systemctl restart t2prochot
    journalctl -u t2prochot -b -n 3 --no-pager -o cat
fi

if [ "$(cat /sys/module/macsmc_hwmon/parameters/fan_control 2>/dev/null)" = "Y" ]; then
    systemctl restart t2fancurve
    echo
    echo "Done. Following the fan log (Ctrl+C to stop watching, the service keeps running):"
    journalctl -u t2fancurve -f -n 5
else
    echo
    echo "Done. Reboot to apply the driver option; the services start automatically after that."
fi
