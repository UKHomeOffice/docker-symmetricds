#! /bin/bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Defaults
default_port="31417"
protocol="https"
auth=""

# Environment variables
source "${SCRIPT_DIR}/env.cfg"

# Set-up param for auth
if [ -n "${USERNAME}" ]; then
  auth="-u ${USERNAME}:${PASSWORD}"
fi

# Handle non-HTTPS case
if [ "${HTTPS}" == "FALSE" ]; then
  default_port="31415"
  protocol="http"
fi

port="${LISTEN_PORT:-${default_port}}"

curl -skSH "Accept: application/json" ${auth} "${protocol}://127.0.0.1:${port}/api/engine/status" > /dev/null
