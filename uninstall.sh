#!/bin/bash
# Removes t2fancurve and t2prochot. Fans return to SMC control when the
# service stops; PROCHOT comes back on the next reboot.
set -e

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo ./uninstall.sh"; exit 1; }

echo "[1/3] Stopping and disabling the services"
systemctl disable --now t2fancurve 2>/dev/null || true
systemctl disable --now t2prochot 2>/dev/null || true

echo "[2/3] Removing files"
rm -fv /etc/systemd/system/t2fancurve.service /usr/local/bin/t2fancurve \
       /etc/systemd/system/t2prochot.service /usr/local/bin/t2prochot \
       /usr/lib/systemd/system-sleep/t2prochot
systemctl daemon-reload

echo "[3/3] Leaving /etc/t2fancurve.conf and /etc/modprobe.d/macsmc-hwmon.conf in place"
echo "      Delete them manually if you no longer need them."
echo
echo "Done. If t2prochot was installed, reboot to restore the default PROCHOT behaviour."
