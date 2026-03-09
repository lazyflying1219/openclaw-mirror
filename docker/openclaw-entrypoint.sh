#!/usr/bin/env bash
set -Eeuo pipefail

/usr/local/lib/openclaw/restore-workspace.sh || true
exec "$@"
