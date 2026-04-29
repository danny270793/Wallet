#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT/flutter"

if [[ ! -f .env.json ]]; then
  echo "error: flutter/.env.json not found (required for SUPABASE_URL / SUPABASE_ANON_KEY dart-defines)" >&2
  exit 1
fi

# Ensures Xcode project is synced with Flutter; embeds compile-time defines from .env.json.
flutter build ios --config-only --dart-define-from-file=.env.json
