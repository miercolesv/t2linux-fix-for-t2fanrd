#!/bin/bash
# Installs t2fancurve and enables it at boot.
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./install.sh"; exit 1; }
cd "$(dirname "$0")"

echo "[1/5] Installing /usr/local/bin/t2fancurve"
install -Dm755 t2fancurve /usr/local/bin/t2fancurve

echo "[2/5] Installing /etc/t2fancurve.conf"
if [ -e /etc/t2fancurve.conf ]; then
    echo "      Existing config kept"
else
    install -Dm644 t2fancurve.conf /etc/t2fancurve.conf
fi

echo "[3/5] Enabling fan control in the macsmc-hwmon driver"
echo "options macsmc-hwmon fan_control=1" > /etc/modprobe.d/macsmc-hwmon.conf

echo "[4/5] Disabling t2fanrd if present"
if systemctl list-unit-files t2fanrd.service >/dev/null 2>&1 && systemctl is-enabled t2fanrd >/dev/null 2>&1; then
    systemctl disable --now t2fanrd
    echo "      t2fanrd disabled"
else
    echo "      Not installed or already disabled"
fi

echo "[5/5] Installing and enabling the systemd service"
install -Dm644 t2fancurve.service /etc/systemd/system/t2fancurve.service
systemctl daemon-reload
systemctl enable t2fancurve

if [ "$(cat /sys/module/macsmc_hwmon/parameters/fan_control 2>/dev/null)" = "Y" ]; then
    systemctl restart t2fancurve
    echo
    echo "Done. Following the log (Ctrl+C to stop watching, the service keeps running):"
    journalctl -u t2fancurve -f -n 5
else
    echo
    echo "Done. Reboot to apply the driver option; the service starts automatically after that."
fi
