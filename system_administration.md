# System Administration

Add a new user
```shell
$ useradd <USERNAME> -u <USER_ID> -s /bin/bash
$ useradd ktrushin -u 1000 -g 1000 --create-home --user-group
```

Add an existing user to an existing group
```shell
$ sudo usermod -aG <group_name> <user_name>
```

Change user uid and gid
```shell
$ usermod -u <NEWUID> <LOGIN>
$ groupmod -g <NEWGID> <GROUP>
```

Merge two directories:
```shell
$ rsync -a source_dir/* dest_dir/
```

Memory a process consumes (in KB)
```shell
$ ps --no-header -C <process_command> -o rss | awk '{rss += $1};END{print rss}'
$ smem -P <process_command> -c pss -H | \
  python3 -c "from fileinput import input; print(sum(map(int, input())))"
```

List hardware on a PC
```shell
$ lshw
$ lspci
$ lsusb
$ inxi
```

Get date as unixtime
```shell
$ date +%s
```

Convert a date to unixtime
```shell
$ date -d "2015-09-04 13:35:00" +%s
```

Convert unixtime to a date
```shell
$ date -d @1451573940
```

Fix Ctrl-Shift-e in terminator
```shell
$ ibus-setup
```
Then remove the keybinding for Emoji

Restart GUI:
1. change to another virtual console using <ctrl+alt+f2>
2. login
3. run `sudo systemctl restart systemd-logind` or `sudo systemctl restart gdm`
4. change back to the virtual console where GUI is bind to using <ctrl+alt+f7>


Install system monitor GNOME extentions on Ubuntu 20.04:
* install required packages
  ```shell
  $ sudo apt-get install gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 \
      gnome-system-monitor gnome-shell-extension-system-monitor
  ```
* restart the machine

Install system monitor GNOME extentions on Ubuntu 22.04:
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
* install the `system-monitor-next` GHOME extension


Lock screen when lid is closed:
* In Gnome Tweaks, enable `General -> Suspend when laptop lid is closed`
* In `/etc/systemd/logind.conf`, uncomment the `HandleLidSwitch` and
  `HandleLidSwitchExternalPower` and change their values as follows:
```
HandleLidSwitch=lock
HandleLidSwitchExternalPower=lock
```

Install Windows 11 into VirtualBox: before installing, disable
Setting -> System -> Enable EFI (special OSes only)


Install HP MFP m137fnw:
01. Connect the printer to the Wi-Fi network via HP Smart app
02. Discover the printer via Settings->Printers menu
02. Install airscan:
```shell
$ sudo apt-get install sane-airscan
```
03. Go to [here](https://support.hp.com/us-en/drivers/printers),
    choose Linux -> Ubuntu and download the driver.
04. Untar the driver and execute `install.sh` with sudo
05. In the `Settings->Printers` menu select the printer settings, hit
    the `Printer Details` button, update the printer name to the desired one and
    hit the `Install PPD file` button, choose the
    `/usr/share/ppd/uld-hp/HP_Laser_MFP_13x_Series.ppd` file.

A data scrubbing command to prevent a bit rot on an external flash-memory-based
drive (SSD, USB flash drive):
```
$ sudo dd if=/dev/disk/by-label/<drive_name> of=/dev/null iflag=nocache status=progress
```
