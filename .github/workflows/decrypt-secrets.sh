#!/bin/bash
set -e

# Decrypt secrets.json to secrets.dec.json using SOPS
sops -d secrets.json > secrets.dec.json