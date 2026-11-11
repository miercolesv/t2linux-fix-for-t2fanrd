# MADE BY CLAUDE FABLE 5.2 but it work fine, i tested myself.
### Includes optional PROCHOT patch to unthrottle 800Mhz limit. 


Fan control for Intel Macs with the T2 chip on Linux kernels that use the `macsmc_hwmon` driver.

From kernel 7.3, T2 Macs moved from the patched `applesmc` driver to the new `macsmc` drivers. Fan daemons written for the old interface, such as t2fanrd, fail with `Error: Fan not found`, and with nothing driving them the SMC runs the fans at full speed.

t2fancurve is a small bash script that reads the CPU and GPU temperature and sets the fan speed on a linear curve: minimum speed below `LOW_TEMP`, maximum speed above `HIGH_TEMP`, proportional in between. The temperature is averaged over a few seconds and the fan speed is ramped rather than jumped, so a short processor burst does not make the fans roar. It has no dependencies beyond bash and systemd.

The repo also includes an optional fix for Macs running without a battery, which are otherwise stuck at 800 MHz (see [t2prochot](#macs-without-a-working-battery-t2prochot)).

## Requirements

- An Intel Mac with a T2 chip
- A kernel with the `macsmc_hwmon` driver loaded. Check with:

  ```
  grep -l macsmc_hwmon /sys/class/hwmon/hwmon*/name
  ```

  If this prints nothing, your kernel still uses `applesmc` and the old daemons should work.

## Install

```
git clone https://github.com/miercolesv/t2linux-fix-for-t2fanrd t2fancurve
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
| `SMOOTHING` | 6       | Seconds the temperature is averaged over; 0 uses the raw reading |
| `RAMP_UP`   | 200     | Fastest the fans may speed up, rpm per second; 0 = no limit |
| `RAMP_DOWN` | 100     | Fastest the fans may slow down, rpm per second; 0 = no limit |

All values are whole numbers. An existing config file is kept on reinstall; settings missing from it use the defaults above.

With the defaults a burst of a second or two is barely audible, and a sustained load takes about 20 to 30 seconds to bring the fans from minimum to maximum. The CPU throttles itself at its maximum temperature in the meantime, as it does under the SMC's own slow fan control. For a quicker response lower `SMOOTHING` or raise `RAMP_UP`; `SMOOTHING=0` with both ramps at `0` gives the old instant behaviour.

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

## Macs without a working battery: t2prochot

If the battery is dead or disconnected, or works but its SMC sensors are dead (`sensors` shows the battery temperatures at -127 °C), the SMC asserts PROCHOT and the CPU is pinned at 800 MHz no matter how cool it is. Check with:

```
sudo modprobe msr
grep MHz /proc/cpuinfo      # stuck at ~800 under load
sudo rdmsr -p0 0x64F        # odd last digit = PROCHOT active
```

`t2prochot` clears bit 0 (BD PROCHOT) of MSR `0x1FC` on every core, so the CPU ignores the SMC's signal. The CPU's own thermal protection still throttles it at its maximum temperature. It needs `msr-tools`:

```
sudo pacman -S msr-tools      # or: apt install msr-tools / dnf install msr-tools
sudo ./install.sh --prochot
```

This adds a boot service and a suspend hook that reapplies the setting after resume. Expect a kernel log warning about an MSR write; it is harmless. It will not work with Secure Boot lockdown enabled, since that blocks MSR writes.

Do not use this on a Mac with a healthy battery. There PROCHOT is protecting the battery and power supply from overload **(or do lol, who is claude to say what you can or can't do. Your mac your rules)**

## Uninstall

```
sudo ./uninstall.sh
```

This removes both tools. The config file and the modprobe option are left in place; delete them by hand if you no longer need them. PROCHOT returns to normal on the next reboot.

## Notes

- When the script stops, it writes `0` to each `fanN_target`. This returns the fans to the SMC, which on some models means full speed. The service restarts automatically if it crashes.
- The temperature used is the higher of `coretemp` (CPU package) and `amdgpu` (discrete GPU, if present). If it cannot be read, the fans go straight to maximum until it can.
- On start the ramp begins from the speed the fans are actually turning at, so taking over from the SMC is gradual too.
- The macOS throttles that the same no-battery condition triggers (kernel_task forced idle and the XCPM P-state limit) do not exist on Linux, so there is nothing to undo for them here.
- hwmon numbers change between boots, so devices are found by name each time the script starts.

## Licence

MIT
