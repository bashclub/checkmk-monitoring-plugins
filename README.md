# checkmk-monitoring-plugins
A collection of monitoring plugins for checkmk >= 2.0

## running-kernel (Checkmk Agent local check)
Compares the running kernel with the latest installed kernel on Debian based systems and will change state to WARN if a newer kernel version is installed and the system needs a reboot.

#### Installation
Just execute the following command to install the plugin on your machine to monitor:
```
wget -O /usr/lib/check_mk_agent/local/check_running_kernel https://github.com/bashclub/checkmk-monitoring-plugins/raw/main/running-kernel/check_running_kernel
chmod +x /usr/lib/check_mk_agent/local/check_running_kernel
```
The check will be detected automatically by CheckMK Discovery.
