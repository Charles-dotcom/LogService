#!/bin/bash
set -euo pipefail

echo "Running SOPS decryption..."

# Optional: debug AWS identity inside the script
aws sts get-caller-identity

# Decrypt the file
sops -d secrets.json > secrets.dec.json

echo "Decryption complete."
