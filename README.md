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
