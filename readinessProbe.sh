#!/bin/bash
set -eo pipefail

LISTEN_PORT="${LISTEN_PORT}"
HTTPS="${HTTPS:-TRUE}"

if [ "${HTTPS}" == "FALSE" ]; then
  LISTEN_PORT="${LISTEN_PORT:-31415}"
else
  LISTEN_PORT="${LISTEN_PORT:-31417}"
fi

curl -H "Accept: application/json" http://127.0.0.1:${LISTEN_PORT}/api/engine/status | jq -e '.started == true'
