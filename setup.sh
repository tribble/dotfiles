#!/usr/bin/env bash
# dotfiles: fresh-machine restore. Idempotent; safe to re-run.
# COPIES repo files into place — never symlinks: a tool writing its config
# through a symlink would write into the repo, and the leak vector returns.
# Existing live files that differ are backed up to <path>.bak-dotfiles-<ts>.
# Usage: setup.sh [--dry-run]
set -euo pipefail
cd "$(dirname "$0")"

dry=0
[ "${1:-}" = "--dry-run" ] && dry=1
run() { if [ "$dry" = 1 ]; then echo "DRY: $*"; else "$@"; fi }

# repo path -> live path. config/X lives at ~/.config/X; VS Code (macOS) reads its
# user files from ~/Library/Application Support/Code/User, not ~/.config;
# launchd reads per-user jobs from ~/Library/LaunchAgents.
live() { case "$1" in vscode/*) echo "$HOME/Library/Application Support/Code/User/${1#vscode/}";; launchagents/*) echo "$HOME/Library/LaunchAgents/${1#launchagents/}";; *) echo "$HOME/.$1";; esac; }

ts=$(date +%Y%m%d%H%M%S)
git ls-files -z 'config/' 'vscode/' 'launchagents/' | while IFS= read -r -d '' rel; do
  case "$rel" in *.template) continue;; esac   # templates: manual, see README
  src="$PWD/$rel"
  dst=$(live "$rel")
  label="${dst/#$HOME/~}"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "ok (same):     $label"
    continue
  fi
  if [ -e "$dst" ]; then
    run cp -a "$dst" "$dst.bak-dotfiles-$ts"
    echo "backed up:     $label -> $label.bak-dotfiles-$ts"
  fi
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  echo "installed:     $label"
done

# pr-watch poller under launchd (launchagents/com.tribble.pr-watch.plist).
# bootout+bootstrap = idempotent (re)load, so an edited plist takes effect and
# the poller restarts on the just-installed pr-watch. macOS only.
if [ "$(uname)" = Darwin ]; then
  if [ -x "$HOME/.local/bin/pr-watch" ]; then
    run mkdir -p "$HOME/.local/state/pr-watch"   # launchd opens the log path before exec; it won't create the dir
    run launchctl bootout "gui/$(id -u)/com.tribble.pr-watch" 2>/dev/null || true
    run launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.tribble.pr-watch.plist"
    echo "launchd:       com.tribble.pr-watch (re)loaded"
  else
    echo "launchd:       com.tribble.pr-watch NOT loaded: ~/.local/bin/pr-watch missing (run ~/work/pi/setup.sh, then re-run this)"
  fi
fi

if git ls-files 'config/' | grep -q '\.template$'; then
  echo
  echo "Templates NOT auto-installed (they need your own values):"
  git ls-files 'config/' | grep '\.template$' | while read -r t; do
    echo "  cp $t ~/.${t%.template}   # then edit"
  done
fi

echo "Done. Backups carry the .bak-dotfiles-$ts suffix; delete them once happy."
