#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-eu-north-1}"

sops -d secrets.json > secrets.dec.json
if [ -f secrets.dec.json ]; then
    echo "Secrets decrypted successfully."
else
    echo "Failed to decrypt secrets."
    exit 1
fi