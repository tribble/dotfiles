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

ts=$(date +%Y%m%d%H%M%S)
git ls-files -z 'config/' | while IFS= read -r -d '' rel; do
  case "$rel" in *.template) continue;; esac   # templates: manual, see README
  src="$PWD/$rel"
  dst="$HOME/.$rel"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    echo "ok (same):     ~/.$rel"
    continue
  fi
  if [ -e "$dst" ]; then
    run cp -a "$dst" "$dst.bak-dotfiles-$ts"
    echo "backed up:     ~/.$rel -> ~/.$rel.bak-dotfiles-$ts"
  fi
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  echo "installed:     ~/.$rel"
done

if git ls-files 'config/' | grep -q '\.template$'; then
  echo
  echo "Templates NOT auto-installed (they need your own values):"
  git ls-files 'config/' | grep '\.template$' | while read -r t; do
    echo "  cp $t ~/.${t%.template}   # then edit"
  done
fi

echo "Done. Backups carry the .bak-dotfiles-$ts suffix; delete them once happy."
