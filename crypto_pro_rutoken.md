Download and install `КриптоПро для Linux` with support of `RuToken Lite`
USB tokens
```
$ mkdir crypto_pro
$ pushd crypto_pro
$ <download_here>
$ ls
$ linux-amd64_deb.tgz
$ tar -xzf linux-amd64_deb.tgz
$ pushd linux-amd64_deb/
$ sudo apt-get install libccid pcscd libpcsclite1 pcsc-tools opensc
$ ./install_gui.sh
$ sudo apt-get install ./cprocsp-rdr-rutoken-64_5.0.12600-6_amd64.deb \
    ./cprocsp-rdr-pcsc-64_5.0.12600-6_amd64.deb \
    ./cprocsp-rdr-cryptoki-64_5.0.12600-6_amd64.deb
```

Install the `Адаптер Рутокен Плагин` browser extension and change the default
token pin code to a new one.

Install two more browsers plugings as described
[here](https://www.cryptopro.ru/products/cades/plugin) and
[here](https://docs.cryptopro.ru/cades/plugin/plugin-installation-unix).

For the computer (and CryptoPro) to see the digital signature token,
one needs to launch the `pcscd` service maually:
```
$ sudo systemctl start pcscd
$ systemctl status pcscd
```
