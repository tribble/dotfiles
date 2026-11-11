# Agent-workstream cheat sheet — pi / herdr / ws

## A code change, start to finish

Ask any full Pi session for the change. It runs the managed flow:

1. Fresh native worktree: `herdr worktree create --cwd <repo> --branch <branch> --base origin/main --path <repo>-worktrees/<branch> --label <branch> --no-focus` (pawprint trees go under `~/work/pawprint-worktrees/<branch>`; main stays `~/work/pawprint`).
2. One bounded Delivery Lead in that tree: `launch_agent({name, role:"delivery-lead", cwd:<tree>, task})` (`managed-coder` is a legacy alias).
3. The Lead launches sequential leaves there: `worker` (Opus/high) → fresh `reviewer` (Sol/xhigh; `reviewFamily:"anthropic"` for OpenAI-authored output) → fixes go to a fresh worker. Add `reviewer-security` for risky changes. The Lead unblocks the leaves and mediates findings. It asks you as soon as work stalls or worker and reviewer disagree; three rounds is the backstop. Your decision goes back to the same Lead.
4. The launching session verifies the integrated result, commits/publishes under your authorization, closes settled panes, then `herdr worktree remove --workspace <id>`.

Neither main writes code. Trivial configuration only: `fixer` (Opus/low) + independent review.

| Role | Model / effort | Does |
|---|---|---|
| coordinator | Astra / medium | plan file, delegates everything, verifies, deploys |
| delivery-lead | Astra / high | owns one high-quality delivery; launches worker + reviewers, mediates, escalates |
| worker / fixer | Opus / high · low | the code |
| reviewer, reviewer-security | Sol / xhigh (Opus with `--review-family anthropic`) | fresh read-only review |
| writer · scout · oracle · debugger | Fable · Sonnet · Sol · Astra | prose · recon · diagnosis · reproduction |

Truth: `~/.pi/agent/configs/session-roles.json`, `managed-code-workflow.md`, `delivery-lead.md`, `delegation.md`.

## Inside pi (you type these)

| Command | Does |
|---|---|
| `/ws [repo\|dir] <purpose>` | new focused herdr workspace + interactive Coordinator; repo ids from `~/.pi/agent/configs/ws.json` (`workos`, `infra`), else a path, else inferred from the purpose |
| `/delegate [--role <role>] [--review-family openai\|anthropic] [--cwd <dir> \| --base <ref>] <name> <task>` | named pane agent, delegated mode, reports back via intercom. Task must contain an `Owner outcome:` block |
| `/fleet` | live agents: state, cwd, `[mine]`/`[yours]` |
| `/release-worktree <cwd>` | release only your own recorded pre-pane failure claim; never removes the tree or branch |
| `/start-ticket <LINEAR-ID> [repo]` | `ws create` + hand the new agent the ticket (coordinator that has not opened the pane yet; never send it to an agent already in the worktree) |
| `/intercom` · `/handover` | peer overlay · hand this session's summary to another |
| `pi -c` / `-r` / `--session <id>` | continue last / pick / exact session (herdr auto-resumes after a server restart) |
| `!cmd` / `!!cmd` | shell from the pi input (bash, not fish) |

Delegation example (copy the user's ask verbatim; the launcher refuses a task without the block):

```text
/delegate --role scout --cwd /Users/pantera/work/workos recon-auth Owner outcome:
Find every caller of refreshSession before we touch it.

Read-only. Return paths and call boundaries.
```

- A launch receipt means the task text reached the pane, not that Pi ran it. Watch: `herdr agent read <name> --source recent-unwrapped --lines 120`.
- Among agents, only the launching session prompts or closes its agents; leaves stay idle until then. You operate your own sessions directly. Agents never answer trust prompts: `herdr agent focus <name>`, answer it yourself.
- Name = sidebar label = intercom name. Refer to agents by name; machine routing (`pr-watch track`, `pr-steer`) takes the intercom session ID from `intercom status`.

## `ws` — human workstreams (worktree + herdr workspace + plain pi)

| Command | Does |
|---|---|
| `ws create <branch> [base] [--model ref[:thinking]]` | fetch, worktree in `<repo>-worktrees/<slug>`, rush install in the background, pi named after the slug |
| `ws ls` — alias `wls` | agent / install / tree / push state per workstream |
| `ws rm <branch> [--force]` | teardown; refuses dirty or unpushed; never deletes the branch |
| `ws open <name> [dir] [--model …]` | plain workspace + named pi, no worktree |
| `ws close <name>` | close an opened workspace; no git state touched |

- Run it from anywhere inside the repo. `--model` passes straight to pi; a qualified ID avoids ambiguity: `--model cloudflare-ai-gateway/<id>:high`.
- Install failed? `cat <repo>/.git/worktrees/<slug>/ws-install.log`. A Node version error means `bash -lc` picked the wrong node: `cd <worktree> && PATH="$(mise where node)/bin:$PATH" sh -c 'node common/scripts/install-run-rush.js install && node common/scripts/install-run-rush.js install-autoinstaller --name lefthook'`.
- This is a convenience for your own hands-on work. Code deliveries go through the managed flow above.

## herdr (tab-completes live names)

| Command | Does |
|---|---|
| `wagents` | all agents: name, status, cwd |
| `wblocked [<name>] [--until <state>] [--timeout <ms>]` | block until an agent (or any working agent) is idle/done/blocked |
| `herdr agent focus <name>` / `attach <name>` | jump to its pane / take the terminal (`prefix q` leaves) |
| `herdr agent prompt <name> "<text>" [--wait]` | send a task or a built-in such as `/reload` (e.g. after a package removal; `agent_prompt_stalled` on a slash command is normal, verify with `herdr pane read <pane> \| grep Reloaded`). Check `herdr agent get` first |
| `herdr agent read <name> --source recent-unwrapped --lines 120` | its recent screen |
| `herdr agent get <name>` | pane ↔ session binding; check it before prompting or closing |
| `herdr pane close <pane-id>` · `herdr worktree remove --workspace <id>` | close a settled pane · remove a clean tree (refuses dirty; never `--force` casually) |
| `herdr notification show <title> [--body <text>]` | toast |

## Herdr TUI (prefix = `ctrl+b`, then release)

| Key | Does |
|---|---|
| `prefix ?` | **all keybindings, searchable — the real cheat sheet** |
| `prefix w` / `prefix g` | workspace picker / goto anything |
| `prefix shift+n` / `prefix shift+g` | new workspace / new worktree workspace |
| `prefix c` · `prefix n` `prefix p` | new tab · next / previous tab |
| `prefix v` / `prefix -` | split right / down |
| `prefix h j k l` | move between panes |
| `prefix z` / `prefix x` | zoom pane / close pane |
| `prefix e` | scrollback in your editor |
| `prefix b` | toggle sidebar |
| `prefix q` | detach — everything keeps running |

- "New agent" = split a pane and run `pi`; detection does the rest. Name it: `herdr agent rename <pane> <name>`.
- Open a URL: **Ctrl+Click**.

## Model

- workspace ⊃ tab ⊃ pane ⊃ agent. Many agents per workspace is fine.
- **One Delivery Lead plus one active leaf per task tree.** Leaves run one after another: the Lead starts the next worker or reviewer only after the previous leaf and its commands are settled and closed. A reviewer reads a finished diff, never a worker's changing one.
- Ownership comes from launch records, not workspace grouping. An agent is yours only if you (or your session) launched it or it was handed over.
