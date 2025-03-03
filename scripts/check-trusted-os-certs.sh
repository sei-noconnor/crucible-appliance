#!/bin/bash

CERT_NAME="my-trusted-cert"
CERT_FILE="./dist/ssl/server/tls/root-ca.crt"
CERT_DIR="/usr/local/share/ca-certificates"
CERT_SYSTEM_DIR="/etc/ssl/certs"

# Function to display usage
usage() {
    echo "Usage: $0 [-n CERT_NAME] [-f CERT_FILE] [-h]"
    echo "  -n, --name      Certificate name"
    echo "  -f, --file      Certificate file path"
    echo "  -h, --help      Display this help message"
    exit 1
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--name) CERT_NAME="$2"; shift ;;
        -f|--file) CERT_FILE="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Function to check if the certificate is already trusted
is_cert_trusted() {
    if [ "$(uname)" == "Darwin" ]; then
        # macOS
        security find-certificate -c "$CERT_NAME" /Library/Keychains/System.keychain > /dev/null 2>&1
    else
        # Linux
        grep -q "$CERT_NAME" "$CERT_SYSTEM_DIR/ca-certificates.crt"
    fi
}

# Function to add the certificate to the trusted store
add_cert_to_trusted() {
    if [ "$(uname)" == "Darwin" ]; then
        # macOS
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_FILE"
    else
        # Linux
        sudo cp "$CERT_FILE" "$CERT_DIR"
        sudo update-ca-certificates
    fi
}

# Check if the certificate is already trusted
if is_cert_trusted; then
    echo "The certificate is already trusted."
else
    echo "The certificate is not trusted. Adding it to the trusted store..."
    add_cert_to_trusted
    echo "The certificate has been added to the trusted store."
fi