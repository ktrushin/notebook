#!/bin/sh

# The script is inspired by
# https://stackoverflow.com/questions/7580508/getting-chrome-to-accept-self-signed-localhost-certificate/60516812#60516812
# and
# https://gist.github.com/fntlnz/cf14feb5a46b2eda428e000157447309

# Note. Please see `man x509v3_config` for the details on X509 V3 certificate
# extension configuration that used for the `-addext` option below.

# Note. The script uses the following abbreviations:
# - `ca` - Certificate Authority
# - `csr` - Certificate Signing Request

set -eu

create_root_ca_creds() {
    org=$1
    openssl req -x509 -new -sha256 -nodes -days 36600 -newkey ed25519 \
        -subj "/C=US/ST=MA/L=Boston/O=$org/OU=IT/CN=$org.com" \
        -addext "keyUsage = critical, keyCertSign" \
        -addext "basicConstraints = critical, CA:TRUE" \
        -addext "subjectKeyIdentifier = hash" \
        -keyout "$org.key" -out "$org.crt"
}

sign_csr() {
    org=$1
    ca_org=$2

    tmp_file=$(mktemp)
    trap "rm -f $tmp_file" EXIT
    echo "authorityKeyIdentifier = keyid:always,issuer:always\n" > $tmp_file

    openssl x509 -req -sha256 -days 36600 -copy_extensions copy -extfile $tmp_file \
        -CA $ca_org.crt -CAkey $ca_org.key -CAcreateserial \
        -in $org.csr -out $org.crt

    rm $tmp_file
    trap - EXIT
}

create_child_ca_creds() {
    child_ca_org=$1
    parent_ca_org=$2

    openssl req -new -nodes -sha256 -newkey ed25519 \
        -subj "/C=US/ST=MA/L=Boston/O=$child_ca_org/OU=IT/CN=$child_ca_org.com" \
        -addext "keyUsage = critical, keyCertSign" \
        -addext "basicConstraints = critical, CA:TRUE" \
        -addext "subjectKeyIdentifier = hash" \
        -keyout $child_ca_org.key -out $child_ca_org.csr

    sign_csr $child_ca_org $parent_ca_org
}

create_org_creds() {
    org=$1
    ca_org=$2

    openssl req -new -nodes -sha256 -newkey ed25519 \
        -subj "/C=US/ST=MA/L=Boston/O=$org/OU=IT/CN=$org.com" \
        -addext "subjectAltName = DNS:$org.com,DNS:*.$org.com,DNS:localhost,IP:127.0.0.1" \
        -addext "keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement" \
        -addext "extendedKeyUsage = serverAuth,clientAuth" \
        -addext "basicConstraints = CA:FALSE" \
        -addext "subjectKeyIdentifier = hash" \
        -keyout $org.key -out $org.csr

    sign_csr $org $ca_org
}

create_root_ca_creds "root-ca"

create_org_creds "server" "root-ca"

create_child_ca_creds "intermediate-ca" "root-ca"
create_org_creds "client" "intermediate-ca"
cat client.key client.crt intermediate-ca.crt > client.pem

create_org_creds "client2" "root-ca"
cat client2.key client2.crt > client2.pem
