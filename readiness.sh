#! /bin/bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Defaults
default_port="31417"
protocol="https"

# Environment variables
source "${SCRIPT_DIR}/env.cfg"

# Handle non-HTTPS case
if [ "${HTTPS}" == "FALSE" ]; then
  default_port="31415"
  protocol="http"
fi

port="${LISTEN_PORT:-${default_port}}"

curl -fskSH "Accept: application/json" "${protocol}://127.0.0.1:${port}/api/engine/status" | jq -e '.started == true'
