# mTLS keys (local-only)

This folder is for **locally generated** mTLS material (offline, no HSM).

- Generate a simple CA, server cert, and client cert from the repo root:
  `./scripts/generate-mtls-keys.sh --key-dir ./keys --san DNS:<host> --san IP:<addr>`
- Provision the server mTLS files to the device after flashing (see
  `scripts/provision-mtls.sh`).

Security note: do **not** commit private keys to a shared repo. Consider keeping this
folder local or encrypting it before sharing.
