# mTLS keys (local-only)

This folder is for **locally generated** mTLS material (offline, no HSM).

- Run `./generate.sh` to create a simple CA, server cert, and client cert.
- The Nix build references these files to place them into the target image.

Security note: do **not** commit private keys to a shared repo. Consider keeping this
folder local or encrypting it before sharing.
