## MADE BY CLAUDE OPUS 5.5 but it work fine, i tested myself.

Fan control for Intel Macs with the T2 chip on Linux kernels that use the `macsmc_hwmon` driver.

From kernel 7.3, T2 Macs moved from the patched `applesmc` driver to the new `macsmc` drivers. Fan daemons written for the old interface, such as t2fanrd, fail with `Error: Fan not found`, and with nothing driving them the SMC runs the fans at full speed.

t2fancurve is a small bash script that reads the CPU and GPU temperature and sets the fan speed on a linear curve: minimum speed below `LOW_TEMP`, maximum speed above `HIGH_TEMP`, proportional in between. It has no dependencies beyond bash and systemd.

## Requirements

- An Intel Mac with a T2 chip
- A kernel with the `macsmc_hwmon` driver loaded. Check with:

  ```
  grep -l macsmc_hwmon /sys/class/hwmon/hwmon*/name
  ```

  If this prints nothing, your kernel still uses `applesmc` and the old daemons should work.

## Install

```
git clone https://github.com/miercolesv/t2fancurve
cd t2fancurve
sudo ./install.sh
```

The installer:

1. Copies the script to `/usr/local/bin/t2fancurve`
2. Creates `/etc/t2fancurve.conf` (an existing one is kept)
3. Writes `options macsmc-hwmon fan_control=1` to `/etc/modprobe.d/macsmc-hwmon.conf`
4. Disables t2fanrd if it is enabled
5. Installs and enables `t2fancurve.service`

If fan control was not already enabled in the driver, reboot once afterwards.

Enabling `fan_control` taints the kernel with a "dangerous option" warning. This is expected: the driver is letting userspace override the SMC.

## Configuration

Edit `/etc/t2fancurve.conf`:

| Setting     | Default | Meaning                                       |
|-------------|---------|-----------------------------------------------|
| `LOW_TEMP`  | 60      | °C at or below which fans run at minimum      |
| `HIGH_TEMP` | 80      | °C at or above which fans run at maximum      |
| `INTERVAL`  | 2       | Seconds between checks                        |

Then apply it:

```
sudo systemctl restart t2fancurve
```

Minimum and maximum speeds are read from the SMC for each fan, so dual-fan models are handled automatically.

## Checking it works

```
journalctl -u t2fancurve -f
```

The first lines show the detected devices and curve. After that a line is logged whenever the temperature or speeds change:

```
52°C -> fan1 1836rpm fan2 1700rpm
```

To run it in the foreground for testing, stop the service and run `sudo /usr/local/bin/t2fancurve`. Ctrl+C hands the fans back to the SMC.

## Uninstall

```
sudo ./uninstall.sh
```

The config file and the modprobe option are left in place; delete them by hand if you no longer need them.

## Notes

- When the script stops, it writes `0` to each `fanN_target`. This returns the fans to the SMC, which on some models means full speed. The service restarts automatically if it crashes.
- The temperature used is the higher of `coretemp` (CPU package) and `amdgpu` (discrete GPU, if present).
- hwmon numbers change between boots, so devices are found by name each time the script starts.

## Licence

MIT
