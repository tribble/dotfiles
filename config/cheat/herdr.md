# herdr fleet ops

| command | does |
| --- | --- |
| `herdr agent list` | all agents: name, status (working/idle/blocked/done), pane, cwd |
| `herdr agent get <name\|pane>` | one agent, including its bound session id — check before prompting or closing |
| `herdr agent focus <name>` / `attach <name>` | jump to its pane / take its terminal (`prefix q` leaves) |
| `herdr agent prompt <name> "<text>" [--wait] [--until <state>]` | submit a prompt; `--wait` returns on the first observed state; `agent_prompt_stalled` on a slash command is normal |
| `herdr agent read <name> --source recent-unwrapped --lines 120` | recent scrollback |
| `herdr agent wait <name> [--until <state>] [--timeout <ms>]` | block until idle/done/blocked |
| `herdr worktree create --cwd <repo> --branch <b> --base origin/main --path <repo>-worktrees/<b> --label <b> --no-focus` | linked worktree + workspace; prints the receipt (`.result.worktree.path`, `.result.workspace.workspace_id`) |
| `herdr worktree remove --workspace <id>` | remove a clean tree and its workspace; refuses dirty; keeps the branch |
| `herdr workspace create --cwd <dir> --label <n>` / `close <id>` | plain workspace / tear it down |
| `herdr agent start <n> --kind pi --pane <id> -- --model <qualified>` | boot pi in a pane at a shell prompt (blocks until ready) |
| `herdr pane close <pane-id>` | close one settled pane |
| `herdr status` | client vs server version; `restart_needed` / `server_binary_stale` |
| `herdr server reload-config` | apply config.toml live |

in pi: `/fleet` status table · `/delegate …` launch a delegated agent · `/ws …` interactive Coordinator — see `cheat`.

gotchas:
- herdr agent name == pi session name == intercom name. Refer to agents by name; route machine messages by the intercom session ID.
- A prompt receipt proves the text landed in the pane, not that Pi consumed it. A stalled or timed-out prompt may still have been delivered: read the pane before resending.
- Close only settled panes you own. An idle label or a closed pane does not prove its background commands exited.
- `--model` on agent start: pi resolves bare names across every configured provider, custom ones included, and accepts a `:high` thinking suffix. Use the qualified form to avoid an ambiguous match, e.g. `-- --model cloudflare-ai-gateway/claude-opus-5-5`. Native leaf profiles always use qualified IDs (`session-roles.json`).
- Trust prompts: agents must not answer them. `herdr agent focus <name>`, answer, then resend the task yourself.
- Open URLs with **Ctrl+Click**. Do not set `[ui] mouse_capture=false`: it breaks sidebar clicks and wheel scrollback.
