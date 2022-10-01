# GnuPG

Generate (interactively) an RSA primary key with encryptiion subkey:
```shell
$ gpg --full-generate-key
```

Generate a non-expiring ed25519 primary key with encryptiion subkey:
```shell
$ gpg --quick-generate-key 'Konstantin Trushin <konstantin.trushin@gmail.com>' future-default default never
```
See [here](https://wiki.debian.org/Subkeys) for adding a signining subkey.

Usefull additional opitons for `--list-keys` and `--list-secret-keys`:
  * --keyid-format=long
  * --fingerprint
  * --with-subkey-fingerprints
  * --with-colons

The option `-k` is a shorthand for `--list-keys`. Similarly, the `-K` option
stands for `--list-secret-keys`.

See keys in a file:
```shell
$ gpg --show-keys /usr/share/keyrings/<some_name>.gpg
```

Generate modern GPG key set:
```shell
$ gpg --quick-generate-key \
    'Konstantin Trushin <konstantin.trushin@gmail.com> (<optional_comment>)' \
    ed25519 cert never
$ export KEYFP=<full_key_fingerprint_without_spaces>
$ gpg --quick-add-key $KEYFP ed25519 sign 5y
$ gpg --quick-add-key $KEYFP cv25519 encr 5y
$ gpg --quick-add-key $KEYFP ed25519 auth 5y
$ gpg -k --fingerprint --keyid-format=long --with-subkey-fingerprints
/home/ktrushin/.gnupg/pubring.kbx
---------------------------------
sec   ed25519/6D1C2CDE70C6F63C 2022-08-22 [C] [expires: 2092-08-04]
      Key fingerprint = 8C97 1CCF 125E 6412 42B0  C3CC 6D1C 2CDE 70C6 F63C
uid                 [ultimate] Konstantin Trushin <konstantin.trushin@gmail.com>
ssb   ed25519/5D40908F681247A8 2022-08-22 [S] [expires: 2027-08-21]
      Key fingerprint = E66A 8DA1 17D5 36B2 2D9E  E896 5D40 908F 6812 47A8
ssb   cv25519/CD758CC69945264A 2022-08-22 [E] [expires: 2027-08-21]
      Key fingerprint = 3541 F2E0 4114 0140 A7D9  A2B0 CD75 8CC6 9945 264A
ssb   ed25519/4AFDDFF72034989B 2022-08-22 [A] [expires: 2027-08-21]
      Key fingerprint = 9A7D 2A0B A9B5 5E67 28C1  2767 4AFD DFF7 2034 989B
```

Choose specific subkey to sign:
```shell
gpg -u 0xDF2D08D3! --sign .....
```
Please note the exclamaition mark `!` after the keyid
