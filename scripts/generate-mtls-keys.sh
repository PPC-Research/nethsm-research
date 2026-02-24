#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/generate-mtls-keys.sh --key-dir <path> --san <entry> [--san <entry> ...]

Options:
  --key-dir <path>  Directory to write keys/certs (required)
  --san <entry>     SubjectAltName entry (repeatable). Format: DNS:host or IP:addr
  -h, --help        Show this help

Examples:
  scripts/generate-mtls-keys.sh --key-dir ./keys \
    --san DNS:rpi-nitrokeyhsm-debug --san IP:192.168.1.191
USAGE
}

key_dir=""
sans=()

while [ $# -gt 0 ]; do
  case "$1" in
    --key-dir)
      key_dir="$2"; shift 2 ;;
    --san)
      sans+=("$2"); shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
done

if [ -z "$key_dir" ]; then
  echo "--key-dir is required." >&2
  usage
  exit 2
fi

if [ "${#sans[@]}" -eq 0 ]; then
  echo "At least one --san entry is required." >&2
  usage
  exit 2
fi

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl not found on PATH. Install it or use: nix shell nixpkgs#openssl -c ${here}/generate-mtls-keys.sh ..." >&2
  exit 1
fi

mkdir -p "$key_dir"
key_dir="$(cd "$key_dir" && pwd)"
cd "$key_dir"

umask 077

if [ ! -f ca.key ] || [ ! -f ca.crt ]; then
  openssl req -x509 -newkey rsa:4096 -days 3650 -nodes \
    -keyout ca.key -out ca.crt -subj "/CN=pkcs11-proxy-ca"
fi

render_san_block() {
  local dns_idx=1
  local ip_idx=1
  local san

  for san in "${sans[@]}"; do
    case "$san" in
      DNS:*)
        printf 'DNS.%s = %s\n' "$dns_idx" "${san#DNS:}"
        dns_idx=$((dns_idx + 1))
        ;;
      IP:*)
        printf 'IP.%s = %s\n' "$ip_idx" "${san#IP:}"
        ip_idx=$((ip_idx + 1))
        ;;
      *)
        echo "Unsupported SAN entry: $san (use DNS: or IP:)" >&2
        exit 1
        ;;
    esac
  done
}

make_server_cert() {
  local name="$1"
  local cn="$2"
  local extfile

  openssl req -newkey rsa:2048 -nodes \
    -keyout "${name}.key" -out "${name}.csr" -subj "/CN=${cn}"

  extfile="$(mktemp)"
  {
    cat <<'EXT'
[ v3_req ]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[ alt_names ]
EXT
    render_san_block
  } > "$extfile"

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
