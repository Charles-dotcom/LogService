#!/bin/bash
set -e
/c/ProgramData/chocolatey/lib/sops/tools/sops.exe -d secrets.json > secrets.dec.json