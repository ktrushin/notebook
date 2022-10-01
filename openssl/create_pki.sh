#!/bin/sh

# The script is inspired by
# https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate/60516812#60516812
# and
# https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309

# Note. The `ca` abbreviation stands for Certificate Authority

set -eu

# Please see `man x509v3_config` for the details on X509 V3 certificate
# extension configuration format
v3_ext_template="\
basicConstraints=CA:TRUE
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
keyUsage=digitalSignature,keyCertSign,cRLSign,nonRepudiation,keyEncipherment,dataEncipherment,keyAgreement
extendedKeyUsage=serverAuth,clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = __DOMAIN__"

create_root_ca_creds() {
  org=$1
  domain="$org.com"
  subject="/C=US/ST=MA/L=Boston/O=$org/OU=IT/CN=$domain"
  openssl req -new -x509 -newkey ed25519 -sha256 -subj "$subject" \
      -addext 'keyUsage=digitalSignature,keyCertSign,cRLSign,nonRepudiation,keyEncipherment,dataEncipherment,keyAgreement' \
      -keyout $org.key -out $org.crt -nodes
}


create_domain_creds() {
  org=$1
  domain="$org.com"
  ca_org=$2
  subject="/C=US/ST=MA/L=Boston/O=$org/OU=IT/CN=$domain"
  echo "$v3_ext_template" | sed s/__DOMAIN__/"$domain"/g > $org.v3.ext

  openssl req -new -newkey ed25519 -sha256 -subj "$subject" \
      -keyout $org.key -out $org.csr -nodes
  openssl x509 -req -in $org.csr -CA $ca_org.crt -CAkey $ca_org.key \
      -CAcreateserial -days 36600 -sha256 -extfile $org.v3.ext \
      -out $org.crt
}

create_root_ca_creds "root-ca"
create_domain_creds "intermediate-ca" "root-ca"
create_domain_creds "client" "intermediate-ca"
cat client.key client.crt intermediate-ca.crt root-ca.crt > client.pem

create_domain_creds "server" "root-ca"

create_domain_creds "client-no-chain" "root-ca"
cat client-no-chain.key client-no-chain.crt > client-no-chain.pem
