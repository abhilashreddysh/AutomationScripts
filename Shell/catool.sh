#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${PWD}/pki"
OPENSSL=$(command -v openssl)
mkdir -p "$BASE_DIR"

# ----------------------------
# Root CA Initialization
# ----------------------------
init_root() {
    mkdir -p "$BASE_DIR/root"/{certs,crl,newcerts,private}
    chmod 700 "$BASE_DIR/root/private"
    touch "$BASE_DIR/root/index.txt"
    echo 1000 > "$BASE_DIR/root/serial"
    echo 1000 > "$BASE_DIR/root/crlnumber"

    echo "[*] Generating Root CA private key..."
    $OPENSSL genrsa -aes256 -out "$BASE_DIR/root/private/ca.key.pem" 4096
    chmod 400 "$BASE_DIR/root/private/ca.key.pem"

    echo "[*] Generating Root CA certificate..."
    $OPENSSL req -new -x509 -days 7300 -sha256 \
        -key "$BASE_DIR/root/private/ca.key.pem" \
        -out "$BASE_DIR/root/certs/ca.cert.pem" \
        -subj "/CN=MyHomelabRootCA"

    echo "[+] Root CA created at $BASE_DIR/root/certs/ca.cert.pem"
}

# ----------------------------
# Intermediate CA Initialization
# ----------------------------
init_intermediate() {
    mkdir -p "$BASE_DIR/intermediate"/{certs,crl,csr,newcerts,private}
    chmod 700 "$BASE_DIR/intermediate/private"
    touch "$BASE_DIR/intermediate/index.txt"
    echo 1000 > "$BASE_DIR/intermediate/serial"
    echo 1000 > "$BASE_DIR/intermediate/crlnumber"

    echo "[*] Generating Intermediate private key..."
    $OPENSSL genrsa -aes256 -out "$BASE_DIR/intermediate/private/intermediate.key.pem" 4096
    chmod 400 "$BASE_DIR/intermediate/private/intermediate.key.pem"

    echo "[*] Generating Intermediate CSR..."
    $OPENSSL req -new -sha256 \
        -key "$BASE_DIR/intermediate/private/intermediate.key.pem" \
        -out "$BASE_DIR/intermediate/csr/intermediate.csr.pem" \
        -subj "/CN=MyHomelabIntermediateCA"

    echo "[*] Signing Intermediate with Root CA..."
    $OPENSSL x509 -req -in "$BASE_DIR/intermediate/csr/intermediate.csr.pem" \
        -CA "$BASE_DIR/root/certs/ca.cert.pem" \
        -CAkey "$BASE_DIR/root/private/ca.key.pem" \
        -CAcreateserial -out "$BASE_DIR/intermediate/certs/intermediate.cert.pem" \
        -days 3650 -sha256 -extensions v3_ca

    cat "$BASE_DIR/intermediate/certs/intermediate.cert.pem" "$BASE_DIR/root/certs/ca.cert.pem" > "$BASE_DIR/intermediate/certs/ca-chain.cert.pem"
    echo "[+] Intermediate CA created."
}

# ----------------------------
# Issue Server Certificate
# ----------------------------
issue_cert() {
    local NAME="$2"   # friendly name for file naming
    local CN="$3"     # actual hostname for CN
    shift 3
    local SAN=("$@")  # optional SANs (DNS/IP)

    local KEY="$BASE_DIR/private/${NAME}.key.pem"
    local CSR="$BASE_DIR/csr/${NAME}.csr.pem"
    local CERT="$BASE_DIR/issued/${NAME}.cert.pem"
    local FULLCHAIN="$BASE_DIR/issued/${NAME}.fullchain.pem"

    mkdir -p "$BASE_DIR"/{issued,private,csr}

    echo "[*] Friendly name: $NAME"
    echo "[*] Common Name (CN): $CN"
    echo "[*] SANs: ${SAN[@]}"

    echo "[*] Generating private key for $CN..."
    $OPENSSL genrsa -out "$KEY" 4096

    echo "[*] Generating CSR for $CN..."
    $OPENSSL req -new -key "$KEY" -out "$CSR" -subj "/CN=$CN"

    # Temporary SAN config
    local EXTFILE
    EXTFILE=$(mktemp)
    echo "[ req ]" > "$EXTFILE"
    echo "distinguished_name=req" >> "$EXTFILE"
    echo "x509_extensions=server_cert" >> "$EXTFILE"
    echo "[ server_cert ]" >> "$EXTFILE"
    echo "basicConstraints=CA:FALSE" >> "$EXTFILE"
    echo "keyUsage = critical, digitalSignature, keyEncipherment" >> "$EXTFILE"
    echo "extendedKeyUsage = serverAuth" >> "$EXTFILE"

    # Add SANs if provided
    if [ "${#SAN[@]}" -gt 0 ]; then
        echo "subjectAltName = @alt_names" >> "$EXTFILE"
        echo "[ alt_names ]" >> "$EXTFILE"
        local i=1
        for san in "${SAN[@]}"; do
            if [[ $san =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "IP.$i = $san" >> "$EXTFILE"
            else
                echo "DNS.$i = $san" >> "$EXTFILE"
            fi
            ((i++))
        done
    fi

    echo "[*] Signing certificate..."
    $OPENSSL x509 -req -in "$CSR" \
        -CA "$BASE_DIR/intermediate/certs/intermediate.cert.pem" \
        -CAkey "$BASE_DIR/intermediate/private/intermediate.key.pem" \
        -CAcreateserial -out "$CERT" -days 825 -sha256 \
        -extfile "$EXTFILE" -extensions server_cert

    # Build fullchain.pem (cert + intermediate + root)
    cat "$CERT" "$BASE_DIR/intermediate/certs/ca-chain.cert.pem" > "$FULLCHAIN"

    rm -f "$EXTFILE"
    chmod 600 "$KEY"

    echo "[+] Certificate issued for $CN"
    echo "    Key: $KEY"
    echo "    Cert: $CERT"
    echo "    Fullchain: $FULLCHAIN"
}

# ----------------------------
# Revoke Certificate
# ----------------------------
revoke_cert() {
    local CERT="$1"
    echo "[*] Revoking $CERT..."
    $OPENSSL ca -config "$BASE_DIR/intermediate/intermediate.cnf" -revoke "$CERT"
    $OPENSSL ca -config "$BASE_DIR/intermediate/intermediate.cnf" -gencrl \
        -out "$BASE_DIR/intermediate/crl/intermediate.crl.pem"
    echo "[+] Certificate revoked."
}

# ----------------------------
# Export Root CA
# ----------------------------
export_root() {
    cp "$BASE_DIR/root/certs/ca.cert.pem" rootCA.crt
    echo "[+] Root CA exported as rootCA.crt"
}

# ----------------------------
# CLI
# ----------------------------
case "${1:-}" in
    init-root) init_root ;;
    init-intermediate) init_intermediate ;;
    issue)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 issue <friendly-name> <CN> [SANs...]"
            exit 1
        fi
        issue_cert "$@"
        ;;
    revoke)
        if [ $# -ne 2 ]; then
            echo "Usage: $0 revoke <cert.pem>"
            exit 1
        fi
        revoke_cert "$2"
        ;;
    export-root) export_root ;;
    *)
        echo "Usage:"
        echo "  $0 init-root"
        echo "  $0 init-intermediate"
        echo "  $0 issue <friendly-name> <CN> [SANs...]"
        echo "  $0 revoke <cert.pem>"
        echo "  $0 export-root"
        exit 1
        ;;
esac