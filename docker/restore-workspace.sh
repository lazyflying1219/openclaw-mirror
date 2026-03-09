#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  echo "[openclaw-restore] $*" >&2
}

warn() {
  echo "[openclaw-restore] WARN: $*" >&2
}

fail_or_warn() {
  if [[ "${OPENCLAW_BACKUP_RESTORE_STRICT:-0}" == "1" ]]; then
    echo "[openclaw-restore] ERROR: $*" >&2
    exit 1
  fi
  warn "$*"
  return 0
}

public_remote() {
  local raw="$1"
  if [[ "$raw" =~ ^https://github\.com/([^/]+)/([^/]+?)(\.git)?/?$ ]]; then
    printf 'https://github.com/%s/%s.git\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  if [[ "$raw" =~ ^([^/[:space:]]+)/([^/[:space:]]+)$ ]]; then
    printf 'https://github.com/%s/%s.git\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

auth_remote() {
  local remote="$1"
  local token="$2"
  if [[ -z "$token" ]]; then
    printf '%s\n' "$remote"
    return 0
  fi
  if [[ "$remote" =~ ^https://github\.com/(.+)$ ]]; then
    printf 'https://x-access-token:%s@github.com/%s\n' "$token" "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

workspace_looks_initialized() {
  local ws="$1"
  [[ -f "$ws/SOUL.md" || -f "$ws/USER.md" || -f "$ws/BACKUP.md" || -d "$ws/memory" ]]
}

MODE="${OPENCLAW_BACKUP_RESTORE_MODE:-if-empty}"
WORKSPACE="${OPENCLAW_WORKSPACE_DIR:-/root/.openclaw/workspace}"
REPO="${OPENCLAW_BACKUP_REPO:-}"
TOKEN="${OPENCLAW_BACKUP_GITHUB_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN:-}}}"
BRANCH="${OPENCLAW_BACKUP_BRANCH:-}"
SNAPSHOT="${OPENCLAW_BACKUP_SNAPSHOT:-latest}"
VERIFY=1
[[ "${OPENCLAW_BACKUP_RESTORE_NO_VERIFY:-0}" == "1" ]] && VERIFY=0

case "$MODE" in
  off)
    log "restore mode is off; skipping workspace restore"
    exit 0
    ;;
  if-empty|always)
    ;;
  *)
    fail_or_warn "Unsupported OPENCLAW_BACKUP_RESTORE_MODE=$MODE"
    exit 0
    ;;
esac

if [[ -z "$REPO" ]]; then
  log "OPENCLAW_BACKUP_REPO is not set; skipping workspace restore"
  exit 0
fi

if [[ "$MODE" == 'if-empty' ]] && workspace_looks_initialized "$WORKSPACE"; then
  log "workspace already looks initialized; skipping restore"
  exit 0
fi

REMOTE_PUBLIC="$(public_remote "$REPO")" || { fail_or_warn "Unsupported backup repo format: $REPO"; exit 0; }
REMOTE_AUTH="$(auth_remote "$REMOTE_PUBLIC" "$TOKEN")" || { fail_or_warn "Could not build authenticated remote for $REMOTE_PUBLIC"; exit 0; }
TMPDIR="$(mktemp -d /tmp/openclaw-restore.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

log "cloning backup repo"
git clone --depth 1 "$REMOTE_AUTH" "$TMPDIR/repo" >/dev/null 2>&1 || { fail_or_warn "Failed to clone backup repo"; exit 0; }
cd "$TMPDIR/repo"

if [[ -n "$BRANCH" ]]; then
  git checkout "$BRANCH" >/dev/null 2>&1 || { fail_or_warn "Failed to checkout branch $BRANCH"; exit 0; }
fi

if [[ "$SNAPSHOT" == 'latest' ]]; then
  [[ -f LATEST_SNAPSHOT.txt ]] || { fail_or_warn 'LATEST_SNAPSHOT.txt not found in backup repo'; exit 0; }
  SNAPSHOT="$(<LATEST_SNAPSHOT.txt)"
fi

SNAPSHOT_DIR="$TMPDIR/repo/snapshots/$SNAPSHOT"
MANIFEST="$TMPDIR/repo/manifests/$SNAPSHOT.sha256"
[[ -d "$SNAPSHOT_DIR" ]] || { fail_or_warn "Snapshot not found: $SNAPSHOT"; exit 0; }
mkdir -p "$WORKSPACE"
cp -a "$SNAPSHOT_DIR/." "$WORKSPACE/"

if [[ $VERIFY -eq 1 ]]; then
  [[ -f "$MANIFEST" ]] || { fail_or_warn "Manifest not found for snapshot $SNAPSHOT"; exit 0; }
  log 'verifying restored workspace'
  (cd "$WORKSPACE" && sha256sum -c "$MANIFEST") || { fail_or_warn 'Workspace verification failed'; exit 0; }
fi

log "workspace restored from snapshot $SNAPSHOT"
