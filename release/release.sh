#!/usr/bin/env bash
# MedicalVault → Firebase App Distribution release (macOS/Linux entry point).
#
# All real logic lives in the canonical Node script, release.mjs, so this
# wrapper only locates Node and forwards arguments — nothing here needs to
# be duplicated or kept in sync across macOS/Linux shells.
#
# Usage:
#   ./release.sh                                   # full release, default notes
#   ./release.sh --notes "Version 1.0.3\n• Fixes"   # inline release notes
#   ./release.sh --notes-file CHANGELOG.txt
#   ./release.sh --groups qa-team,beta-testers --testers alice@x.com,bob@x.com
#   ./release.sh --aab                              # also build an AAB
#   ./release.sh --skip-upload                      # build/package only, no Firebase
#   ./release.sh --dry-run                           # validate version only
#
# Run from anywhere; the script resolves paths relative to its own location.
# Exit code is propagated unchanged from release.mjs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/release.mjs"

if [[ ! -f "$ENGINE" ]]; then
  echo "Release engine not found at $ENGINE" >&2
  exit 1
fi

NODE_BIN="$(command -v node || true)"
if [[ -z "$NODE_BIN" ]]; then
  echo "Node.js is required but was not found on PATH. Install Node 18+ and retry." >&2
  exit 1
fi

exec "$NODE_BIN" "$ENGINE" "$@"
