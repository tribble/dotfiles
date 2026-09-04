#!/usr/bin/env bash
# sync-back: the deliberate, reviewed act of copying a LIVE file back INTO
# the repo. Run it, read `git diff`, then commit. Touches ONLY the exact
# known-safe paths below — never a wildcard sweep.
set -euo pipefail
cd "$(dirname "$0")/.."

paths=(
  config/cheat/herdr.md
  config/cheat/pi.md
  config/cheat/ws.md
  config/herdr/config.toml
  config/fish/conf.d/ws.fish
  config/fish/conf.d/fish_frozen_theme.fish
  config/fish/fish_plugins
  config/starship.toml
  config/git/ignore
  config/mise/config.toml
  # NEVER: config/fish/conf.d/pi.fish (account/gateway IDs — edit the .template instead)
  # NEVER: config/fish/config.fish (live API key), config/mcp/mcp.json (internal hosts)
)

for rel in "${paths[@]}"; do
  src="$HOME/.$rel"
  [ -f "$src" ] || { echo "skip (no live file): ~/.$rel"; continue; }
  if cmp -s "$src" "$rel"; then
    echo "ok (same):        $rel"
  else
    cp "$src" "$rel"
    echo "synced:           ~/.$rel -> $rel"
  fi
done

echo
echo "Review what changed BEFORE committing:"
git diff --stat
