Download and install `КриптоПро для Linux` with support of `RuToken Lite`
USB tokens

Steps:
01. Read the [howto](https://support.cryptopro.ru/index.php?/Knowledgebase/Article/View/390/0/rbot-s-kriptopro-csp-v-linux-n-primere-debian-11) article
02. Sign-in to the site (item 1.1 in the article)
03. Download the distribution (item 1.2 in the article)
04. Install via graphical installer (`install_gui.sh`); don't forget to check
    modules for smart cards and tokens in the list of modules being installed
    (see below)

Commands:
```
$ mkdir crypto_pro
$ pushd crypto_pro
$ <download_here>
$ ls
$ linux-amd64_deb.tgz
$ tar -xzf linux-amd64_deb.tgz
$ pushd linux-amd64_deb/
$ sudo apt-get install libccid pcscd libpcsclite1 pcsc-tools opensc
$ sudo ./install_gui.sh
```
In the list of modules going to be installed, choose (by pressing space key on
the keyboard) `Modules for smart cards and tokens` (not exactly accurate name).
One can choose a module to install by pressing the space key on the keyboard.

Alternatively, install the following packages.
```
$ sudo apt-get install ./cprocsp-rdr-rutoken-64_5.0.12600-6_amd64.deb \
    ./cprocsp-rdr-pcsc-64_5.0.12600-6_amd64.deb \
    ./cprocsp-rdr-cryptoki-64_5.0.12600-6_amd64.deb
```
Versions may change (e.g. `13000` instead of `12600`).

Install the `Адаптер Рутокен Плагин` browser extension and change the default
token pin code to a new one.

(Optional) Install two more browser plugins as described
[here](https://www.cryptopro.ru/products/cades/plugin) and
[here](https://docs.cryptopro.ru/cades/plugin/plugin-installation-unix).

For the computer (and CryptoPro) to see the digital signature token,
one needs to launch the `pcscd` service manually:
```
$ sudo systemctl start pcscd
$ systemctl status pcscd
```

Install Saby as described [here](https://saby.ru/help/start/teh_terms/sbisplugin/install/not_start)

How to use `КриптоПро`:
01. Insert the token into the USB-port
02. Open `CryptoPro Tools`.
03. Go to the `Containers`, click the top one in the list,
    click `Check Container`, enter the pin, click `Install certificate`;
    installing certificate enables signing and encrypting (see below)
04. Go to `Signing`, click `Choose file to sign`, click `Sign`
05. Go to `Encrypt file`, click `Choose file to encrypt`, click `Encrypt`


Before installing or using Saby plug-in (aka СБИС плагин or Sbis plug-in)
change OS interface language to Russian. Otherwise, it won't work properly.
