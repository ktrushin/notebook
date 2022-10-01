# Easy RSA

```shell
$ sudo apt-get install easy-rsa
$ /usr/share/easy-rsa/easyrsa init-pki
$ /usr/share/easy-rsa/easyrsa --batch --req-cn=ZuluCa build-ca nopass
$ /usr/share/easy-rsa/easyrsa --batch build-server-full server nopass
$ EASYRSA_EXTRA_EXTS='subjectAltName=IP:127.0.0.1' \
    /usr/share/easy-rsa/easyrsa --batch build-server-full 127.0.0.1 nopass
$ /usr/share/easy-rsa/easyrsa --batch build-client-full client nopass
```
Optional:
```
$ cat pki/private/client.key pki/issued/client.crt > pki/client.pem
```
