# PI cheat sheet

Config is pawprint (`~/work/pawprint`, applied to `~/.pi/agent`). Never edit `~/.pi` by hand: change the repo, then `setup.sh --apply`. Fitch's kit supplies the session-name and image-guard extensions plus a few packages below.

## Slash commands (you type these)

| Command | Does |
|---|---|
| `/ws`, `/delegate`, `/fleet`, `/release-worktree`, `/start-ticket` | agents and workstreams — see `cheat` (ws) |
| `/costs [days]` · `/costs workstream [full]` | per-model medians · this session + everything it launched, counted once; spending is uncapped |
| `/btw <question>` | ask a side model about this conversation; the card never enters the main context |
| `/recap` | detached session summary, readable after resume (`/recap cancel` stops it) |
| `/ctx` | context-window breakdown: what is eating tokens |
| `/todos` | the persistent todo list (survives compaction and reload) |
| `/stash` / `/stash-list` | park a half-written message, restore later |
| `/edit-turn` (Ctrl+Shift+E) | re-edit or remove an earlier turn in place |
| `/copy-message` / `/copy-user` | copy raw session text without terminal formatting |
| `/cwd` | show/change working dir safely mid-session |
| `/preset plan` / `/preset implement` | read-only planning on Sol/xhigh · implementation tools on high |
| `/compact <what to keep>` · `/new` | trim within a topic · new topic = new session |
| `/done` | finished for good: archive the transcript out of `/resume` (still greppable under `~/.pi/agent/sessions-archive/`) and quit. Ctrl+D leaves it resumable |
| `/intercom` · `/handover` | peer overlay · hand this session over to another |
| `/mcp` | MCP servers: sign in, reconnect, enable/disable. `github` needs no sign-in (uses your `gh` token) |
| `/skill:<name>` | force a skill, e.g. `/skill:ponytail-review`, `/skill:shape` |
| `/extract-process-improvements` | end of a substantial session: durable lessons into AGENTS.md |
| `/github-open-issues-prs` | open issues+PRs across Fitch's repos (his, not yours) |
| `/packages` · `/update` | pins vs upstream (read-only) · update pi + packages now |
| `/reload` · `/trust` · `/name` · `/model` · `/thinking` | built-ins |

## Agent-facing (the model uses them)

- `launch_agent` / `release_worktree` — native pane agents with role profiles; only recorded pre-pane failure claims can be released
- `intercom` — list/send/ask/reply/handover between sessions; IDs from `intercom status`
- `agent_costs` — the `/costs` views for the model
- `todo_list`, `change_dir`, `calculator`, file editing (`apply_patch`, `replace_text`, `write_files`), browser tools (pi-agent-browser-native)

## Skills (auto-load on task match; `/skill:<name>` forces one)

| Skill | Fires when |
|---|---|
| shape | before any build: settle intent, mock visual design, prove one slice |
| verification-before-completion | about to claim done / commit / PR — forces fresh evidence first |
| ask-clarifying-questions | ambiguity that materially changes scope or safety |
| deslop | cleaning AI diff noise out of a change |
| test-audit | writing or sweeping tests |
| ux-review · thermo-nuclear-code-quality-review · code-smells | user-visible review · big structural diffs · smell inventory |
| dogfood | exploratory QA via real browser/terminal |
| diagram-creation | editable D2/SVG diagrams with rendered previews |
| handoff | paste-ready continuation prompt for a new session |
| pi-extension-development | building/debugging pi extensions |
| propose-then-ship-pi | rank one repo improvement, stop, then ship it |
| ponytail · ponytail-review · ponytail-audit | lazy-senior-dev mode (on by default) · change review · whole-repo audit |
| pi-intercom | session-to-session coordination patterns |

## Ponytail watch (how to tell it's hurting)

Ponytail injects persistent "reuse / delete / smallest root-cause fix" pressure. Watch reviewer findings for: out-of-scope deletions, contorted reuse of a near-fit helper, workers under-delivering with "simplified" as the reason, review loops that churn on minimalism. If findings cluster there, `/skill:ponytail-review` on the diff shows what it flags; disable it with `pi config` (toggle ponytail off) or remove the package.

## Manage

- `pi-update` — pi to npm's latest (mise global pin), writes the pin into `~/work/dotfiles/config/mise/config.toml`, commits only that file, pushes. Refuses if that file has uncommitted changes. Running sessions keep the old version.
- `~/work/dotfiles/setup.sh --check` — live vs repo for every dotfile; exit 1 on drift, each line carries the `cp` to keep the live edit. Plain `setup.sh` also restarts pr-watch. `~/work/pawprint/scripts/validate.sh` is the same for `~/.pi`.
- Packages: `/packages` is read-only. `/packages bump|install|remove` only queues a pawprint source task — nothing changed yet. The applied `packages` list replaces the live one wholesale, so a live-only `pi install` is undone by the next apply.
- `pi config` — enable/disable any extension, skill, prompt, theme (Tab = project-local).
- MCP sign-in: `/mcp`. `github` uses your `gh auth token` automatically.
- macOS Keychain prompt storm on MCP calls? Two differently-signed `node` binaries on PATH give pi two Keychain identities. Check `lsof -p <pi pid> | grep bin/node`; keep one node source.
- A child whose transcript ends in `Request timed out.` is paused, not dead. Inspect its transcript, `herdr agent get <pane>` identity, and process/command state first. Prefer prompting that same settled session (UUID still bound) with its original brief; replace it only after the original actor and its commands have settled. A route probe (`pi --print --no-session --model <id> "Reply ok"`) proves connectivity only. Recipe: `~/.pi/agent/configs/managed-code-workflow.md` → Network interruption.
