# Agent-workstream cheat sheet — ws / herdr / pi

## Workstreams (`ws`) — worktree + herdr workspace + pi

| Command | Does |
|---|---|
| `ws create <branch> [base] [--model ref:think]` | new workstream: fetch, worktree, rush install (bg), pi |
| `ws ls` — alias `wls` | state per workstream: agent / install / tree / push |
| `ws rm <branch> [--force]` | teardown; **refuses** dirty/unpushed; branch always kept |
| `ws open <name> [dir] [--model ref:think]` | plain workspace + named pi, no worktree |
| `ws close <name>` | close an opened workspace (no git state touched) |

- Run `ws` from anywhere in a repo — it's repo-relative (worktrees land in `<repo>-worktrees/<slug>`)
- **Always** use `ws create`, never herdr's native worktrees (those skip fetch/install/pi and hide checkouts)
- Space without an agent: `prefix+shift+N`, or `herdr workspace create`

## Herd management (herdr CLI — tab-completes live names)

| Command | Does |
|---|---|
| `wagents` | all agents: name, status, cwd |
| `herdr agent attach <name>` | talk to an agent directly (leave via `prefix+q`) |
| `herdr agent prompt <name> "task"` | send it work — tasks only, never `/slash` commands |
| `herdr agent wait <name> --until blocked` | block until it needs you |
| `herdr agent read <name>` | peek at its screen |
| `herdr notification show <text>` | toast (agents use this too) |

## Herdr TUI (prefix = `ctrl+b`, then release)

| Key | Does |
|---|---|
| `prefix ?` | **all keybindings, searchable — the real cheat sheet** |
| `prefix w` / `prefix g` | workspace picker / goto anything |
| `prefix c` | new tab |
| `prefix v` / `prefix -` | split right / down |
| `prefix h j k l` | move between panes |
| `prefix z` | zoom pane |
| `prefix q` | detach — everything keeps running |
| `prefix [` | copy mode (vim motions, `/` search, `y` yank) |

- "New agent" = no shortcut: split a pane and run `pi` — detection does the rest
- Name it: `herdr agent rename <pane> <name>` (`ws create` names them for you)

## Model

- workspace ⊃ tab ⊃ pane ⊃ agent (recognized process) — many agents per workspace is fine
- **THE rule: one WRITER agent per worktree** — helpers/reviewers/servers share freely
- `ws` convention: worktree ↔ workspace; herdr groups them under the repo (= epics)
- Agent needs its own checkout mid-task? It runs `ws create <branch>` itself

## Inside pi

| Thing | Does |
|---|---|
| `/parallel scout "x" -> oracle "y"` | subagents in-session (pi-subagents) |
| `subagent worktree:true` | bounded task in throwaway worktree, returns diff |
| `bash: ws create …` | agents spawn sibling workstreams themselves |
| `pi -c` / `-r` / `--session <id>` | resume sessions (herdr auto-resumes after server restart) |
| `kimi` — or `pi --preset kimi` | kimi-k3 max + kimi subagents; `/preset` switches live |
| `!cmd` / `!!cmd` | shell from pi input (bash, not fish — shims in `~/.local/bin` bridge) |

## Watching agents
| command | what |
|---|---|
| `wagents` | all live agents: name, status, cwd |
| `wblocked <name>` | block until agent hits idle/done/blocked (`--until <state>` to narrow, `--timeout <ms>`) |
