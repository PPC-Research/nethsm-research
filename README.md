# rpi-nethsm (poor man's NetHSM)

This project builds a small, hardware-platform-agnostic NetHSM proxy using NixOS. The goal is to expose a USB HSM over the network as securely as possible (e.g., TLS-PSK today, and mTLS when the proxy stack supports it), while keeping the host and HSM hardware abstracted so other platforms can be added later.

The current reference platform is:
- Host: Raspberry Pi (Raspberry Pi 4)
- HSM: Nitrokey USB HSM
- Proxy: pkcs11-proxy (ppc-research/pkcs11-proxy)

## Targets

At the moment there is one NixOS target:
- `rpi-nitrokeyhsm-debug` (Raspberry Pi 4 + Nitrokey USB HSM + pkcs11-proxy)

More targets will be added later for different host and HSM combinations.

## Build instructions

Build the SD card image for the current target:

```sh
nix build .#rpi-nitrokeyhsm-debug
```

The image will be produced under `./result/sd-image/*.img`.

## Wi‑Fi configuration (optional)

Wi‑Fi settings live in `nix/hosts/rpi-nitrokeyhsm-debug/wlan.nix`. This file is
ignored by git and must be created locally if you want WLAN enabled.
If you keep it untracked, build with `nix build path:.#rpi-nitrokeyhsm-debug`
so Nix includes local files.

## mTLS keys (local-only)

This repo expects local mTLS material under `keys/` and provisions it to the device
after flashing (nothing is copied into the Nix store or image). Generate a basic
CA, server, and client cert:

```sh
scripts/generate-mtls-keys.sh --key-dir ./keys \
  --san DNS:rpi-nitrokeyhsm-debug --san IP:192.168.1.191
```

Provision the server mTLS files after the device boots:

```sh
scripts/provision-mtls.sh --host <rpi-ip> --user <username>
```

Provision the server mTLS files after the device boots:

```sh
scripts/provision-mtls.sh --host <rpi-ip> --user <username>
```

Do not commit private keys to a shared repo; keep `keys/` local or encrypted.

## Development environment

This flake provides a development shell with the minimal tooling needed to work on and debug the proxy stack:

```sh
nix develop
```

The dev shell includes:
- `opensc`, `pcsc-tools`, `gnutls` for HSM interaction and TLS tooling
- `pkcs11-proxy` (ppc-research fork) for running the proxy locally
- `git`, `nix`

## License

Apache-2.0. See `LICENSE`.
