# OpenSSL

## Manuals
Main manual:
```shell
$ man openssl
```
It describes the utility in general. For a standard command `openssl xxx`,
there usually is a manual page `man openssl-xxx`, for instance `man openssl-req`
or `man openssl-x509`. The full list of those submanuals can be found at the
bottom of openssl main man page.

Please see the `create_pki.sh` script.

# Obtains Human-Readable Information
Print the information from a certificate, key or certificate signing request and
check their integrity where applicable:
```shell
$ openssl x509 -text -noout -in server.crt
$ openssl pkey -text -noout -check -in server.key
$ openssl req -text -noout -verify -in server.csr
```

## Verify Key and Certificate Pair
Check that the key and the certificate match by testing if their md5
checksums match
For RSA keys:
```shell
openssl x509 -noout -modulus -in server.crt | openssl md5
openssl rsa  -noout -modulus -in server.key | openssl md5
```
or modern alternative:
```shell
$ openssl x509 -noout -pubkey -in certificate.crt | openssl md5
$ openssl pkey -pubout -in private.key | openssl md5
```
or even simpler:
```bash
diff <(openssl x509 -noout -pubkey -in certificate.crt) <(openssl pkey -pubout -in private.key)
```

Verify a certificate or certificate chain. There is more than one option for
the most use cases.
```shell
$ openssl verify -verbose -CAfile root-ca.crt server.crt
$
$ openssl verify -verbose -CAfile root-ca.crt -untrusted intermediate-ca.crt client.crt
$
$ cat client.crt intermediate-ca.crt > client_bundle.pem
$ openssl verify -verbose -CAfile root-ca.crt client_bundle.pem
$
$ openssl verify -verbose -CAfile root-ca.crt -untrusted grand-child-ca.crt \
  -untrusted child-ca.crt leaf.crt
$
$ cat grand-child-ca.crt child-ca.crt > intermediate-crt-bundle.pem
$ openssl verify -verbose -CAfile root-ca.crt -untrusted intermediate-crt-bundle.pem leaf.crt
$
$ cat leaf.crt grand-child-ca.crt child-ca.crt > bundle.pem
$ openssl verify -verbose -CAfile root-ca.crt bundle.pem
```

# Misc
Generate private keys:
```shell
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 \
  -out test_rsa.pem -aes-128-cbc --pass pass:hello
$ openssl genpkey -algorithm ed25519 -out test_ed25519.pem \
  -aes-128-cbc --pass pass:hello
```

Example of using OpenSSL's server and client:
```shell
$ cat /path/to/pki/client.key /path/to/pki/client.crt > /path/to/pki/client.pem
$ openssl s_client \
    -CAfile /path/to/pki/ca.crt \
    -cert /path/to/pki/client.pem \
    -connect 127.0.0.1:4433
$ openssl s_server \
    -CAfile /path/to/pki/ca.crt \
    -cert /path/to/pki/server.crt \
    -key /path/to/pki/server.key \
    -port 4433 -Verify 1 -tls1_2
```

OpenSSL's directory and certificate directories on Ubuntu 22.04
```shell
$ openssl version -d
OPENSSLDIR: "/usr/lib/ssl"
$ ls -l /usr/lib/ssl
total 4
lrwxrwxrwx 1 root root   14 Apr 17 18:12 certs -> /etc/ssl/certs
drwxr-xr-x 2 root root 4096 May  8 12:23 misc
lrwxrwxrwx 1 root root   20 Apr 17 18:12 openssl.cnf -> /etc/ssl/openssl.cnf
lrwxrwxrwx 1 root root   16 Apr 17 18:12 private -> /etc/ssl/private
$ ls -l /etc/ssl/
total 32
drwxr-xr-x 2 root root 12288 May  8 12:23 certs
-rw-r--r-- 1 root root 12419 Apr 17 18:12 openssl.cnf
drwx------ 2 root root  4096 Apr 17 18:12 private
$ ls -l /etc/ssl/certs/
total 540
lrwxrwxrwx 1 root root     23 May  8 12:23  002c0b4f.0 -> GlobalSign_Root_R46.pem
...

lrwxrwxrwx 1 root root     58 May  8 12:23  GlobalSign_Root_R46.pem -> /usr/share/ca-certificates/mozilla/GlobalSign_Root_R46.crt
...
lrwxrwxrwx 1 root root     44 May  8 12:23  cbf06781.0 -> Go_Daddy_Root_Certificate_Authority_-_G2.pem
...
lrwxrwxrwx 1 root root     79 May  8 12:23  Go_Daddy_Root_Certificate_Authority_-_G2.pem -> /usr/share/ca-certificates/mozilla/Go_Daddy_Root_Certificate_Authority_-_G2.crt
$ ls -l /usr/share/ca-certificates/
total 12
drwxr-xr-x 2 root root 12288 May  8 12:23 mozilla
$ ls -l /usr/share/ca-certificates/mozilla/
total 496
...
-rw-r--r-- 1 root root 1972 Dec  5  2022  GlobalSign_Root_CA_-_R6.crt
...
-rw-r--r-- 1 root root 1367 Dec  5  2022  Go_Daddy_Root_Certificate_Authority_-_G2.crt
...
```
