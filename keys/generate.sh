#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

umask 077

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found on PATH. Install it or use: nix shell nixpkgs#openssl -c ./generate.sh" >&2
  exit 1
fi

if [ ! -f ca.key ] || [ ! -f ca.crt ]; then
  openssl req -x509 -newkey rsa:4096 -days 3650 -nodes \
    -keyout ca.key -out ca.crt -subj "/CN=pkcs11-proxy-ca"
fi

make_server_cert() {
  local name="$1"
  local cn="$2"
  local extfile

  openssl req -newkey rsa:2048 -nodes \
    -keyout "${name}.key" -out "${name}.csr" -subj "/CN=${cn}"

  extfile="$(mktemp)"
  cat > "$extfile" <<'EXT'
[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = pkcs11-proxy
DNS.2 = rpi-nitrokeyhsm-debug
IP.1 = 127.0.0.1
EXT

  openssl x509 -req -in "${name}.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${name}.crt" -days 825 -sha256 -extfile "$extfile" -extensions v3_req

  rm -f "$extfile"
}

make_client_cert() {
  local name="$1"
  local cn="$2"
  local extfile

  openssl req -newkey rsa:2048 -nodes \
    -keyout "${name}.key" -out "${name}.csr" -subj "/CN=${cn}"

  extfile="$(mktemp)"
  cat > "$extfile" <<'EXT'
[ v3_req ]
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
EXT

  openssl x509 -req -in "${name}.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out "${name}.crt" -days 825 -sha256 -extfile "$extfile" -extensions v3_req

  rm -f "$extfile"
}

if [ ! -f server.key ] || [ ! -f server.crt ]; then
  make_server_cert server pkcs11-proxy
fi

if [ ! -f client.key ] || [ ! -f client.crt ]; then
  make_client_cert client pkcs11-proxy-client
fi

echo "Generated: ca.crt, server.crt, client.crt (and corresponding .key/.csr files)"
