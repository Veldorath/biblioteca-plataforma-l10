#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/comun.sh"
az vm deallocate -g "$G" -n bff
az vm deallocate -g "$G" -n gw-azure
az vm list -g "$G" -d --query '[].{vm:name,estado:powerState}' -o table
