# herdr fleet ops

| command | does |
| --- | --- |
| `herdr agent list` | all agents: name, status (working/idle/done), pane, cwd |
| `herdr agent focus <name>` | jump to an agent's pane |
| `herdr agent prompt <name> "<text>"` | submit a prompt (waits for readiness if started fresh) |
| `herdr agent read <name>` | dump pane scrollback |
| `herdr agent wait <name>` | block until state transition |
| `herdr workspace create --cwd <dir> --label <n>` | new workspace; returns root pane id |
| `herdr agent start <n> --kind pi --pane <id>` | boot pi in a pane (blocks until ready) |
| `herdr workspace close <id>` | tear down |

in pi: `/fleet` status table · `/delegate <name> <task>` spawn+handoff

gotchas:
- prompt right after `agent start` races pi TUI init — settle ~5s (built into /delegate)
- herdr agent name == intercom name; pane agents are fully reachable
- headless subagents: invisible to herdr; only the parent relay reaches them
- `--model` on agent start: pi's BARE-name resolution only searches the built-in catalog (filtered to authenticated providers) — custom models.json providers need the qualified form: `-- --model cloudflare-ai-gateway/kimi-k3`
- open URLs: **Ctrl+Click** (user-verified on 0.8.2; herdr's modified-click modifier, opens in browser; Shift+⌘+Click also works via host-terminal bypass). Do NOT set [ui] mouse_capture=false: it breaks sidebar clicks + wheel scrollback
