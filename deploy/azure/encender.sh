#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/comun.sh"
az vm start -g "$G" -n gw-azure
az vm start -g "$G" -n bff
az vm list -g "$G" -d --query '[].{vm:name,estado:powerState,ip:publicIps}' -o table
