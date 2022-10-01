# OpenSSL

## Manuals
Main manual:
```shell
$ man openssl
```
It describes the utility in general. For a standard command `openssl xxx`,
there usually is a manual page `man xxx`. For instance `man rsa` or `man x509`.
The full list of those submanuals can be found at the bottom of openssl main
man page.

## Generate a private key and a certificate
```shell
$ openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
   -subj "/C=US/ST=WA/L=Seattle/O=Meow/OU=IT/CN=www.meow.com" \
   -keyout www.meow.com.key -out www.meow.com.cert
```

This only generates a certificate with bare mininum of information resulting
in serious tools or libraries (e.g. python's requrests) complaining with
errors/warnings when trying to connect to the server with such a certificate.

A cleaner approach consists of the following steps:
1. generate root key and certificate for pseudo-certificate authority (CA);
2. using the root certificate, generate the key and the certificate
   for a domain;
3. make client trust the root certificate, e.g. for python's requests library,
   pass the path to the root certificate in `verify` parameter of
   the function `request`.
Steps #1 and #2 can be accomplished with `create_key_and_cert.sh` script.
The step #3 may require additional actions. For instance, if the server
with the certificate generated in #2 uses the domain `foo.com` but is launched
on the localhost, the `requests` module may require non-standard DNS as
described [here](https://stackoverflow.com/a/57477670/3111000).

## Check key/cert pair
Check a certificate, key or certificate signing request and print info
about them:
```shell
$ openssl x509 -in server.crt -text -noout
$ openssl rsa -in server.key -check
$ openssl req -text -noout -verify -in server.csr
```

Check that the key and the certificate match by testing if their md5
checksums match
```shell
openssl x509 -noout -modulus -in server.crt | openssl md5
openssl rsa  -noout -modulus -in server.key | openssl md5
```

Generage a private keys:
```shell
$ openssl genpkey -algorithm rsa -pkeyopt rsa_keygen_bits:4096 \
  -out test_rsa.pem -aes-128-cbc --pass pass:hello
$ openssl genpkey -algorithm ed25519 -out test_ed25519.pem \
  -aes-128-cbc --pass pass:hello
```

Show a key:
```shell
$ openssl pkey -in /path/to/the/key.pem
```

View a certificate
```shell
$ openssl x509 -in etc/pki2/root-ca.crt -text -noout
```

Verify a certificate chain:
```shell
$ openssl verify -verbose -CAfile root-ca.crt -untrusted intermediate-ca.crt client.crt
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
