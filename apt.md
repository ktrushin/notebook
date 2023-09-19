Adding a GPG public key of a third-party repository, Wine as an example:
```shell
$ wget -O - https://dl.winehq.org/wine-builds/winehq.key | \
  gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/winehq.gpg
```
Note that the key should be:
1. dearmored if required
2. placed into the file with the `gpg` extension

Another popular place for storing repository keys is
`/usr/share/keyrings/`, e.g.
```shell
$ wget -O- https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```
