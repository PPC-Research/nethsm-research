#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/provision-mtls.sh --host <ip/host> --user <user> [options]

Options:
  --key-dir <path>    Directory with mTLS files (default: ./keys)
  --port <port>       SSH port (default: 22)
  --identity <path>   SSH identity file (optional)
  --with-client       Also upload client.crt/client.key (optional)
  --no-restart        Do not restart pkcs11-proxy after install

Required files (server):
  ca.crt, server.crt, server.key
USAGE
}

host=""
user=""
key_dir="./keys"
port="22"
identity=""
with_client="false"
no_restart="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      host="$2"; shift 2 ;;
    --user)
      user="$2"; shift 2 ;;
    --key-dir)
      key_dir="$2"; shift 2 ;;
    --port)
      port="$2"; shift 2 ;;
    --identity)
      identity="$2"; shift 2 ;;
    --with-client)
      with_client="true"; shift ;;
    --no-restart)
      no_restart="true"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage; exit 2 ;;
  esac
done

if [ -z "$host" ] || [ -z "$user" ]; then
  echo "--host and --user are required." >&2
  usage
  exit 2
fi

required_files=("ca.crt" "server.crt" "server.key")
if [ "$with_client" = "true" ]; then
  required_files+=("client.crt" "client.key")
fi

for f in "${required_files[@]}"; do
  if [ ! -s "$key_dir/$f" ]; then
    echo "Missing or empty file: $key_dir/$f" >&2
    exit 1
  fi
done

ssh_opts=(-p "$port")
scp_opts=(-P "$port")
if [ -n "$identity" ]; then
  ssh_opts+=( -i "$identity" )
  scp_opts+=( -i "$identity" )
fi

remote="$user@$host"

tmpdir=$(ssh "${ssh_opts[@]}" "$remote" 'mktemp -d /tmp/pkcs11-proxy-mtls.XXXXXX')

cleanup() {
  ssh "${ssh_opts[@]}" "$remote" "rm -rf '$tmpdir'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

scp "${scp_opts[@]}" "${required_files[@]/#/$key_dir/}" "$remote:$tmpdir/" >/dev/null

ssh "${ssh_opts[@]}" "$remote" \
  "sudo install -d -m 0750 -o root -g pkcs11-proxy /etc/pkcs11-proxy/mtls && \
   sudo install -m 0440 -o root -g pkcs11-proxy '$tmpdir/ca.crt' /etc/pkcs11-proxy/mtls/ca.crt && \
   sudo install -m 0440 -o root -g pkcs11-proxy '$tmpdir/server.crt' /etc/pkcs11-proxy/mtls/server.crt && \
   sudo install -m 0440 -o root -g pkcs11-proxy '$tmpdir/server.key' /etc/pkcs11-proxy/mtls/server.key"

if [ "$with_client" = "true" ]; then
  ssh "${ssh_opts[@]}" "$remote" \
    "sudo install -m 0440 -o root -g pkcs11-proxy '$tmpdir/client.crt' /etc/pkcs11-proxy/mtls/client.crt && \
     sudo install -m 0440 -o root -g pkcs11-proxy '$tmpdir/client.key' /etc/pkcs11-proxy/mtls/client.key"
fi

if [ "$no_restart" != "true" ]; then
  ssh "${ssh_opts[@]}" "$remote" "sudo systemctl restart pkcs11-proxy.service"
fi

echo "Provisioned mTLS files to $remote:/etc/pkcs11-proxy/mtls"
