#!/usr/bin/env bash
# dotfiles: fresh-machine restore. Idempotent; safe to re-run.
# COPIES repo files into place — never symlinks: a tool writing its config
# through a symlink would write into the repo, and the leak vector returns.
# Existing live files that differ are backed up to <path>.bak-dotfiles-<ts>.
# Usage: setup.sh [--dry-run | --check]
#   --check: report drift between repo and live files, change nothing, exit 1 on any.
set -euo pipefail
cd "$(dirname "$0")"

dry=0 check=0 fail=0
[ "${1:-}" = "--dry-run" ] && dry=1
[ "${1:-}" = "--check" ] && check=1
run() { if [ "$dry" = 1 ]; then echo "DRY: $*"; else "$@"; fi }

# repo path -> live path. config/X lives at ~/.config/X; VS Code (macOS) reads its
# user files from ~/Library/Application Support/Code/User, not ~/.config;
# launchd reads per-user jobs from ~/Library/LaunchAgents; local/X goes to ~/.local/X.
live() { case "$1" in vscode/*) echo "$HOME/Library/Application Support/Code/User/${1#vscode/}";; launchagents/*) echo "$HOME/Library/LaunchAgents/${1#launchagents/}";; *) echo "$HOME/.$1";; esac; }

ts=$(date +%Y%m%d%H%M%S)
while IFS= read -r -d '' rel; do   # process substitution, not a pipe: $fail must survive the loop
  case "$rel" in *.template) continue;; esac   # templates: manual, see README
  src="$PWD/$rel"
  dst=$(live "$rel")
  label="${dst/#$HOME/~}"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "ok (same):     $label"
    continue
  fi
  if [ "$check" = 1 ]; then
    if [ -e "$dst" ]; then echo "DRIFT:         $label   keep live: cp $label $rel"
    else echo "MISSING:       $label   install: setup.sh"; fi
    fail=$((fail + 1)); continue
  fi
  if [ -e "$dst" ]; then
    run cp -a "$dst" "$dst.bak-dotfiles-$ts"
    echo "backed up:     $label -> $label.bak-dotfiles-$ts"
  fi
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  echo "installed:     $label"
done < <(git ls-files -z 'config/' 'vscode/' 'launchagents/' 'local/')

# Homebrew init moved from the unmanaged config.fish (runs after conf.d) to
# conf.d/brew.fish (runs before mise activation). Remove exactly the old
# 5-line block from the top of config.fish; every other byte stays. Only once
# the live brew.fish matches the repo, so no shell is left without Homebrew.
fish_cfg="$HOME/.config/fish/config.fish"
brew_block='if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
    eval (/usr/local/bin/brew shellenv)
end'
if [ -f "$fish_cfg" ] && [ ! -L "$fish_cfg" ] && head -n 5 "$fish_cfg" | cmp -s - <(printf '%s\n' "$brew_block"); then
  if [ "$check" = 1 ]; then
    echo "DRIFT:         ~/.config/fish/config.fish   still runs Homebrew init after mise; fix: setup.sh"
    fail=$((fail + 1))
  elif [ "$dry" = 1 ] || ! cmp -s config/fish/conf.d/brew.fish "$HOME/.config/fish/conf.d/brew.fish"; then
    echo "pending:       ~/.config/fish/config.fish   Homebrew init block kept until conf.d/brew.fish is installed"
  else
    cp -a "$fish_cfg" "$fish_cfg.bak-dotfiles-$ts"
    tail -n +6 "$fish_cfg.bak-dotfiles-$ts" >"$fish_cfg"
    echo "migrated:      ~/.config/fish/config.fish   Homebrew init block removed (now conf.d/brew.fish); backup .bak-dotfiles-$ts"
  fi
elif [ -f "$fish_cfg" ] && grep -q 'brew shellenv' "$fish_cfg"; then
  echo "WARNING:       ~/.config/fish/config.fish   runs brew shellenv in an unexpected form; remove it by hand (conf.d/brew.fish does it now)"
  if [ "$check" = 1 ]; then fail=$((fail + 1)); fi
fi

if [ "$check" = 1 ]; then
  if [ "$fail" = 0 ]; then echo "VALID: live == repo"; exit 0; fi
  echo "INVALID: $fail mismatches" >&2; exit 1
fi

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
