#!/bin/bash
# Removes t2fancurve. Fans return to SMC control when the service stops.
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./uninstall.sh"; exit 1; }

echo "[1/3] Stopping and disabling the service"
systemctl disable --now t2fancurve 2>/dev/null || true

echo "[2/3] Removing files"
rm -fv /etc/systemd/system/t2fancurve.service /usr/local/bin/t2fancurve
systemctl daemon-reload

echo "[3/3] Leaving /etc/t2fancurve.conf and /etc/modprobe.d/macsmc-hwmon.conf in place"
echo "      Delete them manually if you no longer need them."
echo
echo "Done."
