#!/usr/bin/env bash
# Thin wrapper around scripts/bootstrap_mongo.py.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python scripts/bootstrap_mongo.py "$@"
