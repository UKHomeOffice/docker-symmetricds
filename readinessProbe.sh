#!/bin/bash
set -eo pipefail

curl -H "Accept: application/json" http://127.0.0.1:31415/api/engine/status | jq -e '.started == true'
