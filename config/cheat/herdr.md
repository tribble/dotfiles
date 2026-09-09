# herdr fleet ops

| command | does |
| --- | --- |
| `herdr agent list` | all agents: name, status (working/idle/done), pane, cwd |
| `herdr agent focus <name>` | jump to an agent's pane |
| `herdr agent prompt <name> "<text>" --wait` | submit a prompt; `--wait` returns on first observed state (`--until working` to pin) |
| `herdr agent read <name>` | dump pane scrollback |
| `herdr agent wait <name>` | block until state transition |
| `herdr workspace create --cwd <dir> --label <n>` | new workspace; returns root pane id |
| `herdr agent start <n> --kind pi --pane <id>` | boot pi in a pane (blocks until ready) |
| `herdr workspace close <id>` | tear down (native worktree groups need `--group`) |
| `herdr status` | client vs server version; `restart_needed` / `server_binary_stale` |
| `herdr server reload-config` | apply config.toml live (returns diagnostics) |

in pi: `/fleet` status table · `/delegate <name> <task>` spawn+handoff

gotchas:
- ≥0.9: `agent prompt` confirms text+Enter landed before returning — no settle needed (3/3 verified; /delegate's 5s sleep removed)
- ≥0.9: `brew upgrade herdr` no longer requires a server restart — check `herdr status`; brew services restarting the server is what kills the layout, not herdr
- ≥0.9: pane images on by default (`terminal.kitty_graphics`); sidebar `[ui.sidebar.agents] rows` tokens take `rules = [{contains=…, fg=…, bold=…}]` (state coloring set in config.toml)
- herdr agent name == intercom name; pane agents are fully reachable
- headless subagents: invisible to herdr; only the parent relay reaches them
- `--model` on agent start: pi's BARE-name resolution only searches the built-in catalog (filtered to authenticated providers) — custom models.json providers need the qualified form: `-- --model cloudflare-ai-gateway/kimi-k3`
- open URLs: **Ctrl+Click** (user-verified on 0.8.2; herdr's modified-click modifier, opens in browser; Shift+⌘+Click also works via host-terminal bypass). Do NOT set [ui] mouse_capture=false: it breaks sidebar clicks + wheel scrollback
