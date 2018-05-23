#! /bin/bash

set -euo pipefail

default_port="31415"
protocol="https"

if [ "${HTTPS:-}" == "FALSE" ]; then
  default_port="31415"
  protocol="http"
fi

port="${LISTEN_PORT:-${default_port}}"

curl -sSH "Accept: application/json" "${protocol}://127.0.0.1:${port}/api/engine/status" | jq -e '.started == true'
