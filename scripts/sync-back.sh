#!/usr/bin/env bash
# sync-back: the deliberate, reviewed act of copying a LIVE file back INTO
# the repo. Run it, read `git diff`, then commit. Touches ONLY the exact
# known-safe paths below — never a wildcard sweep.
set -euo pipefail
cd "$(dirname "$0")/.."

paths=(
  config/cheat/herdr.md
  config/cheat/pi.md
  config/cheat/pr.md
  config/cheat/ws.md
  config/herdr/config.toml
  config/fish/conf.d/ws.fish
  config/fish/conf.d/pr.fish
  config/fish/conf.d/aws.fish
  config/fish/conf.d/fish_frozen_theme.fish
  config/fish/fish_plugins
  config/starship.toml
  config/git/ignore
  config/mise/config.toml
  vscode/settings.json
  vscode/tasks.json
  vscode/keybindings.json
  # NEVER: config/fish/conf.d/pi.fish (account/gateway IDs — edit the .template instead)
  # NEVER: config/fish/config.fish (live API key), config/mcp/mcp.json (internal hosts)
)

# repo path -> live path; same mapping as setup.sh.
live() { case "$1" in vscode/*) echo "$HOME/Library/Application Support/Code/User/${1#vscode/}";; *) echo "$HOME/.$1";; esac; }

for rel in "${paths[@]}"; do
  src=$(live "$rel")
  label="${src/#$HOME/~}"
  [ -f "$src" ] || { echo "skip (no live file): $label"; continue; }
  if cmp -s "$src" "$rel"; then
    echo "ok (same):        $rel"
  else
    cp "$src" "$rel"
    echo "synced:           $label -> $rel"
  fi
done

echo
echo "Review what changed BEFORE committing:"
git diff --stat
