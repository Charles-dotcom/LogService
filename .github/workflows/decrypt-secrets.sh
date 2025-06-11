#!/bin/bash
set -e
sops -d secrets.json > secrets.dec.json