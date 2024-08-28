#!/bin/bash
#
# Copyright 2022 Carnegie Mellon University.
# Released under a BSD (SEI)-style license, please see LICENSE.md in the
# project root or contact permission@sei.cmu.edu for full terms.
#
# ./generate-certs <gencert arguments>
DOMAIN=$1
shift
ARGS=$*
HOST_JSON=$(cat <<EOF
{
  "names": [
      {
      "C": "US"
      }
  ],
  "key": {
      "algo": "rsa",
      "size": 2048
  },
  "CN": "Crucible Appliance Host",
  "hosts": ["$DOMAIN", "*.$DOMAIN"]
}
EOF
)

CONFIG_JSON=$(cat <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "ca": {
        "usages": [
          "cert sign"
        ],
        "expiry": "87600h"
      },
      "intca": {
        "usages": [
          "signing",
          "key encipherment",
          "cert sign",
          "crl sign"
        ],
        "expiry": "43800h",
        "ca_constraint": {
          "is_ca": true,
          "max_path_len": 0,
          "max_path_len_zero": true
        }
      },
      "client": {
        "usages": [
          "signing",
          "key encipherment",
          "client auth"
        ],
        "expiry": "17520h"
      },
      "server": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "17520h"
      }
    }
  }
}
EOF
)

INTCA_JSON=$(cat <<EOF
{
  "names": [
    {
      "C": "US",
      "O": "Crucible Appliance Intermediate CA"
    }
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "CN": "Crucible Appliance Intermediate CA"
}
EOF
)

ROOTCA_JSON=$(cat <<EOF
{
  "names": [
    {
      "organization": "Crucible Appliance Root CA"
    }
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "CN": "Crucible Appliance Root CA"
}
EOF
)

# Write config files 
# Change to the current directory
DIR=$(dirname ${BASH_SOURCE[0]})
cd "$DIR"
SCRIPTS_DIR=${PWD}

if [ ! -d "$SCRIPTS_DIR/../dist/ssl" ]; then 
  echo  "Createing Directory ./dist/ssl"
  mkdir -p "$SCRIPTS_DIR/../dist/ssl"
fi
# Check for root-ca PEM file so we don't clobber certificates
if [ ! -f "$SCRIPTS_DIR/../dist/ssl/root-ca.pem" ]; then
  echo "$HOST_JSON" > $SCRIPTS_DIR/../dist/ssl/host.json
  echo "$CONFIG_JSON" > $SCRIPTS_DIR/../dist/ssl/config.json
  echo "$INTCA_JSON" > $SCRIPTS_DIR/../dist/ssl/int-ca.json
  echo "$ROOTCA_JSON" > $SCRIPTS_DIR/../dist/ssl/root-ca.json

  # Generate root, intermediate and host certificates/keys
  cfssl gencert $ARGS -initca $SCRIPTS_DIR/../dist/ssl/root-ca.json | cfssljson -bare $SCRIPTS_DIR/../dist/ssl/root-ca
  cfssl gencert $ARGS -ca $SCRIPTS_DIR/../dist/ssl/root-ca.pem -ca-key $SCRIPTS_DIR/../dist/ssl/root-ca-key.pem -config $SCRIPTS_DIR/../dist/ssl/config.json \
                -profile intca $SCRIPTS_DIR/../dist/ssl/int-ca.json | cfssljson -bare $SCRIPTS_DIR/../dist/ssl/int-ca
  cfssl gencert $ARGS -ca $SCRIPTS_DIR/../dist/ssl/int-ca.pem -ca-key $SCRIPTS_DIR/../dist/ssl/int-ca-key.pem -config $SCRIPTS_DIR/../dist/ssl/config.json \
                -profile server $SCRIPTS_DIR/../dist/ssl/host.json | cfssljson -bare $SCRIPTS_DIR/../dist/ssl/host

  # Create pkcs12 host bundle for identity signing key
  openssl pkcs12 -export -out $SCRIPTS_DIR/../dist/ssl/host.pfx -inkey $SCRIPTS_DIR/../dist/ssl/host-key.pem -in $SCRIPTS_DIR/../dist/ssl/host.pem \
                -passin pass:tartans@1 -passout pass:tartans@1
else
  echo "Certificates exists not overwriting"
fi
# sed -ri "s|(signer:) \"\"|\1 $(base64 -w0 host.pfx)|" ../common/identity.values.yaml
