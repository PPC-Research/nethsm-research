# mTLS keys (local-only)

This folder is for **locally generated** mTLS material (offline, no HSM).

- Run `./generate.sh` to create a simple CA, server cert, and client cert.
- Provision the server mTLS files to the device after flashing (see
  `scripts/provision-mtls.sh`).

Security note: do **not** commit private keys to a shared repo. Consider keeping this
folder local or encrypting it before sharing.
