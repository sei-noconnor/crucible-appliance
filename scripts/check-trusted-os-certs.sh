#!/bin/bash

CERT_FILE="./dist/ssl/server/tls/root-ca.crt"
CERT_DIR="/usr/local/share/ca-certificates"
CERT_SYSTEM_DIR="/etc/ssl/certs"

# Function to display usage
usage() {
    echo "Usage: $0 [-f CERT_FILE] [-h]"
    echo "  -f, --file      Certificate file path"
    echo "  -h, --help      Display this help message"
    exit 1
}

# Parse command line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--file) CERT_FILE="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Extract certificate name (CN) — optional, for display only
extract_cert_name() {
    openssl x509 -noout -subject -in "$CERT_FILE" | sed -n 's/^.*CN = \(.*\)$/\1/p'
}

# Get fingerprint of the input certificate
get_cert_fingerprint() {
    openssl x509 -noout -fingerprint -sha256 -in "$CERT_FILE" | sed 's/.*=//;s/://g'
}

# Get fingerprints of trusted certs (Linux)
get_trusted_fingerprints_linux() {
    find "$CERT_SYSTEM_DIR" -type f \( -name '*.pem' -o -name '*.crt' \) 2>/dev/null | while read cert; do
        openssl x509 -noout -fingerprint -sha256 -in "$cert" 2>/dev/null | sed 's/.*=//;s/://g'
    done
}

# Check if the certificate is already trusted
is_cert_trusted() {
    local cert_fingerprint
    cert_fingerprint=$(get_cert_fingerprint)

    if [ "$(uname)" == "Darwin" ]; then
        security find-certificate -a -p /Library/Keychains/System.keychain | \
        awk 'BEGIN {c=0} /BEGIN CERT/{c++} {print > "/tmp/cert" c ".pem"}'
        for f in /tmp/cert*.pem; do
            trusted_fp=$(openssl x509 -noout -fingerprint -sha256 -in "$f" 2>/dev/null | sed 's/.*=//;s/://g')
            if [[ "$trusted_fp" == "$cert_fingerprint" ]]; then
                rm /tmp/cert*.pem
                return 0
            fi
        done
        rm /tmp/cert*.pem
        return 1
    else
        get_trusted_fingerprints_linux | grep -q "$cert_fingerprint"
    fi
}

# Add the certificate to the trusted store
add_cert_to_trusted() {
    if [ "$(uname)" == "Darwin" ]; then
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_FILE"
    else
        sudo cp "$CERT_FILE" "$CERT_DIR"
        sudo update-ca-certificates
    fi
}

# Main logic
cert_name=$(extract_cert_name)
echo "Checking trust status for certificate: $cert_name"

if is_cert_trusted; then
    echo "✅ The certificate is already trusted."
else
    echo "⚠️  The certificate is NOT trusted. Adding it to the trusted store..."
    add_cert_to_trusted
    echo "✅ The certificate has been added to the trusted store."
fi
