When an Ubuntu Wi-Fi adapter is detected (seen by the system) but is "down" or
disconnected, it usually indicates a driver issue, power management conflict,
or that the Network Manager service needs to be restarted.

Here are the most effective solutions, ordered from simplest to most advanced:

1. Restart Network Manager
Often, the network management service has simply crashed or frozen.
```shell
$ sudo systemctl restart NetworkManager
```
If you are using a USB adapter, unplug it and plug it back in after running
this command

## 2. Bring the Interface Up Manually
If the adapter is listed but not active, you can force it up.
Find your interface name (e.g., wlan0, wlp3s0):
```bash
$ ip link show
```
Bring it up:
```bash
$ sudo ip link set <interface_name> up
```
Alternatively, try: `sudo ifconfig <interface_name> up`.

## 3. Check for Hardware/Software Switches (Airplane Mode)
Your Wi-Fi might be blocked by a physical switch on the laptop or by software (RF-Kill). 
Check for blocks:
```bash
$ rfkill list
```
If it says "Hard blocked" or "Soft blocked", unlock it:
```bash
$ sudo rfkill unblock wifi
```
Ensure your laptop's WiFi function key (e.g., Fn+F2) hasn't disabled the card. 

### 4. Reinstall/Update Drivers (If "Additional Drivers" lists options)
If `lsusb` or `lspci` shows the device but it doesn't work, you may need
restricted drivers. Open `Software & Updates`. Go to the `Additional Drivers`
tab. If a driver is listed for your wireless card, select it and click
`Apply Changes`.

## 5. Disable Power Saving
Sometimes the Wi-Fi card powers down to save energy and fails to wake up. 
Edit the NetworkManager configuration:
```bash
$ sudo nano /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
```
Change `wifi.powersave = 3` to `wifi.powersave = 2` (2 means disabled).
Save, exit (`Ctrl+O`, `Enter`, `Ctrl+X`), and restart the service:
`sudo systemctl restart NetworkManager`.

## 6. Power Cycle (Hard Shutdown)
If you dual-boot with Windows or recently had a kernel update, the card might
be in a weird state. Shut down the computer completely. Unplug the power cable
and remove the battery (if possible). Hold the power button for 30 seconds.

## 7. Reinstall Kernel Modules
If the driver is corrupted, reinstalling the firmware modules can fix it.
```bash
$ sudo apt install --reinstall linux-firmware
$ sudo apt install --reinstall linux-modules-extra-$(uname -r)
```
Then reboot. 


Need to know the specific model?
Run this command to see what driver your device is currently using:
```bash
$ lspci -nnk | grep -iA3 net
```
