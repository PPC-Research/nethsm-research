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
- Connect ethernet or Wi‑Fi (see optional WLAN setup below).
- Plug in the Nitrokey USB HSM.
- Power on the Pi.

## Optional: enable WLAN

Create `nix/hosts/rpi-nitrokeyhsm-debug/wlan.nix` locally (this file is ignored
by git). Example:

```nix
{ ... }:

{
  networking.useNetworkd = true;
  systemd.network.networks."10-wlan" = {
    matchConfig.name = "wlan0";
    networkConfig.DHCP = "yes";
    dhcpV4Config.UseHostname = true;
  };

  networking.wireless = {
    enable = true;
    userControlled.enable = false;
    interfaces = [ "wlan0" ];
    extraConfig = "country=FI";
    networks."YOUR-SSID".psk = "YOUR-PSK";
  };
}
```

If you keep `wlan.nix` untracked, build the image with:

```sh
nix build path:.#rpi-nitrokeyhsm-debug
```

## 6) SSH into the device

Before building the image, add your user in
`nix/hosts/rpi-nitrokeyhsm-debug/users.nix` under `users.users.<username>`.
This file is optional and can be kept untracked, similar to `wlan.nix`.
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
export PKCS11_PROXY_SOCKET="tls://<rpi-ip>:2345"
export PKCS11_PROXY_TLS_MODE=cert
export PKCS11_PROXY_TLS_CA_FILE="$(pwd)/keys/ca.crt"
export PKCS11_PROXY_TLS_CERT_FILE="$(pwd)/keys/client.crt"
export PKCS11_PROXY_TLS_KEY_FILE="$(pwd)/keys/client.key"
export PKCS11_PROXY_TLS_VERIFY_PEER=true
```

Then run your PKCS#11 client tool against the proxy. If you are using OpenSC:

```sh
pkcs11-tool --module <pkcs11-proxy-client-module> -L
```

Replace `<pkcs11-proxy-client-module>` with the client-side module/library
provided by your pkcs11-proxy stack.

### 8.4 OpenSSL 3 + PKCS#11 provider (client-side)

If you want to use the proxy with OpenSSL 3, load a PKCS#11 provider and point
it at `libpkcs11-proxy.so`.

1) Install a PKCS#11 provider for OpenSSL 3 (for example, `pkcs11-provider`).
2) Create a config file like this:

```ini
# openssl-pkcs11.cnf
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
pkcs11 = pkcs11_sect

[default_sect]
activate = 1

[pkcs11_sect]
# Path to the provider module
module = /path/to/pkcs11-provider.so
# Path to the PKCS#11 module (the proxy client library)
pkcs11-module = /path/to/libpkcs11-proxy.so
activate = 1
```

3) Run OpenSSL with the config:

```sh
OPENSSL_CONF=/path/to/openssl-pkcs11.cnf openssl list -providers
```

Example: sign a file using a PKCS#11 private key (adjust the URI):

```sh
OPENSSL_CONF=/path/to/openssl-pkcs11.cnf \
openssl pkeyutl -sign \
  -provider pkcs11 -provider default \
  -inkey "pkcs11:token=<token-label>;object=<key-label>;type=private" \
  -in /path/to/input.bin -out /path/to/signature.bin
```

## Notes and troubleshooting

- Build failures complaining about missing `keys/*.crt` mean the keys were not
  generated before the build.
- The mTLS keys are copied into the Nix store as part of the build. For real
  deployments, switch to a proper secret management mechanism or generate keys
  on first boot.
- If you change Wi‑Fi credentials or host settings, rebuild the image and flash
  again.
- If `pkcs11-tool` fails with `certificate verify failed`, your server cert SAN
  likely does not include the host/IP you are connecting to. Regenerate the
  server cert with the correct SANs or connect using a DNS name that is already
  present in the cert.
- For quick testing only, you can disable peer verification on the client:
  `export PKCS11_PROXY_TLS_VERIFY_PEER=false`. Do not use this in production.
