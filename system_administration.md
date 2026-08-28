# System Administration

## User management
```shell
# add a new user
$ useradd <USERNAME> -u <USER_ID> -s /bin/bash
$ useradd ktrushin -u 1000 -g 1000 --create-home --user-group
$
# add an existing user to an existing group
$ sudo usermod -aG <group_name> <user_name>
$ sudo usermod -aG lp,scanner $USER
$
# change user uid and gid
$ usermod -u <NEWUID> <LOGIN>
$ groupmod -g <NEWGID> <GROUP>
```

## Resource monitoring and limiting
Memory a process consumes (in KB)
```shell
$ ps --no-header -C <process_command> -o rss | awk '{rss += $1};END{print rss}'
$ smem -P <process_command> -c pss -H | \
  python3 -c "from fileinput import input; print(sum(map(int, input())))"
```

Permanently increase open file limit for a user:
01. Execute the following:
    ```shell
    $ echo "$USER hard nofile 1048576" | sudo tee -a /etc/security/limits.conf
    $ echo "$USER soft nofile 1048576" | sudo tee -a /etc/security/limits.conf
    $ echo 'session required pam_limits.so' | sudo tee -a /etc/pam.d/common-session
    ```
01. Restart the machine or log out and log in


## Miscellaneous Recipes
The `date` command cheat sheet:
```shell
# get date as unixtime
$ date +%s
#
# convert a date to unixtime
$ date -d "2015-09-04 13:35:00" +%s
#
# convert unixtime to a date
$ date -d @1451573940
```

Merge two directories:
```shell
$ rsync -a source_dir/* dest_dir/
```

Restart GUI:
1. change to another virtual console using <ctrl+alt+f2>
2. login
3. run `sudo systemctl restart systemd-logind` or `sudo systemctl restart gdm`
4. change back to the virtual console where GUI is bind to using <ctrl+alt+f7>


Install Windows 11 into VirtualBox: before installing, disable
Settings -> System -> Enable EFI (special OSes only)


## Ubuntu Post-Installation Setup
Install system monitor GNOME extensions on Ubuntu 22.04:
* remove `chrome-gnome-shell`
  ```shell
  $ sudo apt-get purge chrome-gnome-shell
  ```
* install `gnome-browser-connector` of version 42.0 or higher
  ```shell
  $ sudo apt-get update && sudo apt-get install gnome-browser-connector
  ```
* alternatively, compile `gnome-browser-connector` from source and install
  manually
  ```shell
  $ sudo apt-get install git meson
  $ git clone https://gitlab.gnome.org/nE0sIghT/gnome-browser-connector.git
  $ cd gnome-browser-connector
  $ meson --prefix=/usr builddir
  $ sudo install -C builddir
  ```
* install required packages
  ```shell
  $ sudo apt-get install gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 \
    gnome-system-monitor
  ```
* restart the machine
* install the `system-monitor-next` GNOME extension
* alternatively, go the extension GitHub
  [page](https://github.com/mgalgs/gnome-shell-system-monitor-next-applet)
  and build from sources as described there


Lock screen when lid is closed:
* In Gnome Tweaks, enable `General -> Suspend when laptop lid is closed`
* In `/etc/systemd/logind.conf`, uncomment the `HandleLidSwitch` and
  `HandleLidSwitchExternalPower` and change their values as follows:
```
HandleLidSwitch=lock
HandleLidSwitchExternalPower=lock
```

X selection: copy primary to clipboard
On Ubuntu 24.04 and 26.04 the `Ctrl + Insert` keybinding does that out of the box
For earlier versions, do the following:
- install `xsel`
  ```
  $ sudo apt-get install xsel
  ```
- add a keyboard shortcut `Ctrl + Insert` with the command
  `sh -c 'xsel --output --primary | xsel --input --clipboard'`
  and the name `x_selections_copy_primary_to_clipboard`


## Networking
Test connectivity to the default gateway:
```shell
$ ip route show
default via 192.168.100.1 ...
...
$  ping -W 0.5 -c 20 192.168.100.1
PING 192.168.100.1 (192.168.100.1) 56(84) bytes of data.
64 bytes from 192.168.100.1: icmp_seq=1 ttl=64 time=2.58 ms
...
```
or
```shell
$ ping -W 0.5 -c 20 $(ip route show | head -n 1 | cut -f3 -d' ')
PING 192.168.100.1 (192.168.100.1) 56(84) bytes of data.
64 bytes from 192.168.100.1: icmp_seq=1 ttl=64 time=2.60 ms
...
```

## Hardware
List hardware on a PC
```shell
$ lshw
$ lspci
$ lsusb
$ inxi
```

Set up HP MFP m137fnw:
01. Add yourself to a couple of groups and restart the system:
    ```shell
    $ sudo usermod -aG lp,scanner $USER
    ```
01. Connect the printer to the Wi-Fi network with the printer's menu:
    - using the wifi password or
    - pin code in WPS
    - or push-button WPS flow
01. Via a printer's menu, timeout before going to the stand-by mode to 3 hours,
    otherwise network connectivity may be lost and you will have to manually
    awake the printer and restart the computer to rediscover it
01. Update the printer's firmware via its menu
01. Discover the printer on a laptopvia Settings->Printers menu
01. Install airscan:
    ```shell
    $ sudo apt-get install sane-airscan
    ```
01. Go to [here](https://support.hp.com/us-en/drivers/printers),
    choose Linux -> Ubuntu and download the driver.
01. Untar the driver and execute `install.sh` with sudo
01. In the `Settings->Printers` menu select the printer settings, hit
    the `Printer Details` button, update the printer name to the desired one and
    hit the `Install PPD file` button, choose the
    `/usr/share/ppd/uld-hp/HP_Laser_MFP_13x_Series.ppd` file.


A data scrubbing command to prevent a bit rot on an external flash-memory-based
drive (SSD, USB flash drive):
```
$ sudo dd if=/dev/disk/by-label/<drive_name> of=/dev/null iflag=nocache status=progress
```

Logitech Spotlight
Connect the device _via bluetooth_, not via a dongle. To enable the pairing mode
on the device, hold the top and the bottom buttons simultaneously for 3 sec.
To connect an already paired device, press the big `>` button three times.
Start `projecteur` using the command:
```shell
$ QT_QPA_PLATFORM=xcb projecteur
```
Check `Enable multi-screen overlay`. Change other settings if required, then
close the window. Projecteur remains active (see the icon on the top panel) and
doesn't intervene into your presentation.
