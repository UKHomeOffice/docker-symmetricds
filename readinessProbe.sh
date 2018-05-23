#!/bin/bash
set -eo pipefail

LISTEN_PORT="${LISTEN_PORT}"
HTTPS="${HTTPS:-TRUE}"
PROTOCOL="https"

if [ "${HTTPS}" == "FALSE" ]; then
  LISTEN_PORT="${LISTEN_PORT:-31415}"
  PROTOCOL="http"
else
  LISTEN_PORT="${LISTEN_PORT:-31417}"
  PROTOCOL="https"
fi

curl -H "Accept: application/json" "${PROTOCOL}://127.0.0.1:${LISTEN_PORT}/api/engine/status" | jq -e '.started == true'
