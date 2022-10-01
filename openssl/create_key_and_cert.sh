#!/bin/sh

# The script is based on
# https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate/60516812#60516812
# and
# https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309

set -eu

v3_ext_template="\
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = __DOMAIN__"

create_root_key_and_cert() {
  openssl genrsa -out root_ca.key 4096
  openssl req -x509 -new -nodes -key root_ca.key -sha256 \
    -subj '/C=RU/ST=Moscow/L=Moscow/O=Meow/OU=IT/CN=*.meow.com' \
    -days 36600 -out root_ca.crt
}

create_domain_key_and_cert() {
  domain=$1
  subject="/C=CA/ST=None/L=NB/O=None/OU=IT/CN=*.$domain"
  day_count=36600
  echo "$v3_ext_template" | sed s/__DOMAIN__/"$domain"/g > $domain.v3.ext
  openssl req -new -newkey rsa:4096 -sha256 -nodes -subj "$subject" \
    -keyout $domain.key -out $domain.csr
  openssl x509 -req -in $domain.csr -CA root_ca.crt -CAkey root_ca.key \
    -CAcreateserial -days $day_count -sha256 -extfile $domain.v3.ext \
    -out $domain.crt
}

create_root_key_and_cert
create_domain_key_and_cert "alpha.com"
