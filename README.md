# dotfiles

Hand-tuned `~/.config` that used to live only on this disk. Modeled on
[pawprint](https://github.com/tribble/pawprint): default-deny `.gitignore` —
nothing is tracked unless explicitly allowlisted there.

## Install

```sh
git clone <repo-url> ~/work/dotfiles && ~/work/dotfiles/setup.sh
```

`setup.sh` **copies** `repo/config/...` → `~/.config/...`, `repo/vscode/...`
→ `~/Library/Application Support/Code/User/...` (where VS Code on macOS reads
its user files) and `repo/launchagents/...` → `~/Library/LaunchAgents/...`
(never symlinks — a tool writing through a symlink would write into the
repo). Live files that differ are backed up to `<path>.bak-dotfiles-<ts>`
first. On macOS it then (re)loads the `com.tribble.pr-watch` launchd job
(`launchctl bootout` + `bootstrap`), which needs `~/.local/bin/pr-watch` from
`~/work/pi/setup.sh` first. Idempotent; safe to re-run.
`setup.sh --dry-run` prints the plan without touching anything.

Files marked `.template` are NOT auto-installed — they mix safe structure
with secrets. Install manually and fill in your own values:

```sh
cp config/fish/conf.d/pi.fish.template ~/.config/fish/conf.d/pi.fish  # then edit
```

The filled-in `pi.fish` is never versioned (the default-deny `.gitignore`
does not allowlist it).

## Keeping a change (live → repo)

Edits happen in the live files. When one is worth keeping, run:

```sh
scripts/sync-back.sh   # copies live → repo for an explicit known-safe list
```

That copy is the review moment: the script touches only the hardcoded paths
in its `paths=(...)` list (never a wildcard sweep) and prints `git diff --stat`
afterwards. Read the diff, then commit.

## What's managed

| Live path | Repo path | Notes |
|---|---|---|
| `~/.config/cheat/herdr.md` | `config/cheat/herdr.md` | cheat sheet (`cheat herdr`) |
| `~/.config/cheat/pi.md` | `config/cheat/pi.md` | cheat sheet (`cheat pi`) |
| `~/.config/cheat/pr.md` | `config/cheat/pr.md` | cheat sheet (`cheat pr`); edited as `~/work/pi/pr-review/CHEATSHEET.md` (the live path is a symlink to it, `~/work/pi` is not a git repo) |
| `~/.config/cheat/ws.md` | `config/cheat/ws.md` | cheat sheet (`cheat`, default topic) |
| `~/.config/herdr/config.toml` | `config/herdr/config.toml` | herdr UI/toast/theme prefs |
| `~/.config/fish/conf.d/ws.fish` | `config/fish/conf.d/ws.fish` | ws/herdr functions + live completions |
| `~/.config/fish/conf.d/pr.fish` | `config/fish/conf.d/pr.fish` | `pr-review` + `pr-checkout` completion: PR numbers from pr-watch's cache, `pr-<n>` worktrees after `--clean`, flags (see `~/work/pi/pr-review/README.md`) |
| `~/.config/fish/conf.d/fish_frozen_theme.fish` | `config/fish/conf.d/fish_frozen_theme.fish` | hand-picked theme colors (written by `fish_config`) |
| `~/.config/starship.toml` | `config/starship.toml` | prompt theme |
| `~/.config/git/ignore` | `config/git/ignore` | global gitignore |
| `~/.config/mise/config.toml` | `config/mise/config.toml` | global toolchain pin (node 24) |
| `~/Library/Application Support/Code/User/settings.json` | `vscode/settings.json` | VS Code user settings |
| `~/Library/Application Support/Code/User/tasks.json` | `vscode/tasks.json` | user task `Send selection to PR agent` → `pr-note --here` (see `~/work/pi/pr-review/README.md`) |
| `~/Library/Application Support/Code/User/keybindings.json` | `vscode/keybindings.json` | `ctrl+alt+n` runs that task on a selection |
| `~/Library/LaunchAgents/com.tribble.pr-watch.plist` | `launchagents/com.tribble.pr-watch.plist` | launchd job running `pr-watch run` (`KeepAlive`; survives herdr/terminal/pi quits); absolute paths + explicit `PATH` because launchd expands neither. Log: `~/.local/state/pr-watch/launchd.log` |

## Deliberately excluded

| Path | Why |
|---|---|
| `~/.config/fish/conf.d/pi.fish` | Contains Cloudflare account/gateway IDs — versioned as `pi.fish.template` instead; copy + fill in your own |
| `~/.config/fish/config.fish` | Contains a live `BASETEN_API_KEY`. Rotate the key, strip it to env, then reconsider. |
| `~/.config/mcp/mcp.json` | Contains internal hostnames (workos[.]tools / workos[.]cloud) |
| `~/.config/fish/conf.d/git.fish`, `fish-ssh-agent.fish`, `~/.config/fish/functions/` | fisher/plugin-vendored; reinstall via fisher |
| `~/.config/starship.toml.bak` | stale backup |
| `~/.config/ghostty/` | already managed by pawprint |

## Notes

- Repo-local identity: `user.name=tribble`, `user.email=tribble@users.noreply.github.com`.
- Secret hygiene here is structural, not hook-based: the default-deny
  `.gitignore` means a new file is never tracked until you deliberately
  allowlist it. Read the staged diff before committing — there is no
  automated guard.
