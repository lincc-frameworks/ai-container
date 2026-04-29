#!/usr/bin/env bash
set -euo pipefail

# Browserless-friendly helper; tries known device-code style login variants.
if codex auth login --help >/dev/null 2>&1; then
  if codex auth login --help 2>&1 | grep -q -- '--device'; then
    exec codex auth login --device
  fi
  exec codex auth login
fi

if codex login --help >/dev/null 2>&1; then
  if codex login --help 2>&1 | grep -q -- '--device'; then
    exec codex login --device
  fi
  exec codex login
fi

echo "Unable to find a codex login command. Try running 'codex' and follow interactive auth prompts." >&2
exit 1
