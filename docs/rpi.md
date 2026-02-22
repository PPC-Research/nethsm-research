# rpi-nethsm (Raspberry Pi 4 + Nitrokey USB HSM)

This document describes the end-to-end flow to build, install, and run the
`rpi-nitrokeyhsm-debug` target.

## 1) Clone the repo

```sh
git clone <REPO_URL>
cd nethsm-research
```

## 2) Generate local mTLS material (offline)

These files are used for mTLS and are copied into the image at
`/etc/pkcs11-proxy/mtls` during `nix build`.

```sh
./keys/generate.sh
```

Outputs (local-only):
- `keys/ca.crt`
- `keys/server.crt`, `keys/server.key`
- `keys/client.crt`, `keys/client.key`

Do **not** commit private keys to a shared repo.

## 3) Build the SD card image

```sh
nix build .#rpi-nitrokeyhsm-debug
```

The image is produced under:

```
./result/sd-image/*.img
```

## 4) Flash the SD card

Replace `/dev/sdX` with your SD card device.

```sh
sudo dd if=./result/sd-image/*.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Or use a GUI flasher (Balena Etcher, Raspberry Pi Imager, etc.).

## 5) Boot the Raspberry Pi

- Insert the SD card.
- Connect ethernet or Wi‑Fi (current config uses Wi‑Fi credentials in
  `nix/hosts/rpi-nitrokeyhsm-debug/configuration.nix`).
- Plug in the Nitrokey USB HSM.
- Power on the Pi.

## 6) SSH into the device

Before building the image, add your user in
`nix/hosts/rpi-nitrokeyhsm-debug/configuration.nix` under `users.users.<username>`.
That user is what you will use for SSH.
Example:

```sh
ssh <username>@<rpi-ip>
```

## 7) Verify the proxy service

```sh
systemctl status pkcs11-proxy
journalctl -u pkcs11-proxy -b
```

The proxy listens on TCP port `2345` by default.

## 8) Local client setup (mTLS + pkcs11-proxy)

This is a basic example of using the generated mTLS material to connect to the
proxy from your workstation.

### 8.1 Trust the CA

```sh
cp keys/ca.crt /tmp/pkcs11-proxy-ca.crt
```

### 8.2 Use mTLS with OpenSSL (basic sanity check)

If the proxy stack supports mTLS, you can test a TLS handshake:

```sh
openssl s_client \
  -connect <rpi-ip>:2345 \
  -CAfile keys/ca.crt \
  -cert keys/client.crt \
  -key keys/client.key
```

You should see a successful handshake if the server is configured for mTLS.

### 8.3 PKCS#11 proxy client usage (example)

Assuming you have a client tool that speaks to `pkcs11-daemon` over TLS, set
environment variables pointing to your mTLS files. Exact variables depend on
the client, but a typical pattern is:

```sh
export PKCS11_DAEMON_SOCKET="tls://<rpi-ip>:2345"
export PKCS11_PROXY_TLS_PSK_FILE=""   # leave empty if using mTLS
export PKCS11_PROXY_TLS_CA="$(pwd)/keys/ca.crt"
export PKCS11_PROXY_TLS_CERT="$(pwd)/keys/client.crt"
export PKCS11_PROXY_TLS_KEY="$(pwd)/keys/client.key"
```

Then run your PKCS#11 client tool against the proxy. If you are using OpenSC:

```sh
pkcs11-tool --module <pkcs11-proxy-client-module> -L
```

Replace `<pkcs11-proxy-client-module>` with the client-side module/library
provided by your pkcs11-proxy stack.

## Notes and troubleshooting

- Build failures complaining about missing `keys/*.crt` mean the keys were not
  generated before the build.
- The mTLS keys are copied into the Nix store as part of the build. For real
  deployments, switch to a proper secret management mechanism or generate keys
  on first boot.
- If you change Wi‑Fi credentials or host settings, rebuild the image and flash
  again.
