# PI — pi-fitch-kit additions cheat sheet

Installed 2026-08-25 from `github.com/fitchmultz/pi-fitch-kit` (kit is filtered:
no session-name / clean-footer / fast-mode / anthropic-image-guard; also skipped
pi-verbosity-control and macuse). Drift check anytime: `/fitch-setup verify`.

## Slash commands (you type these)

| Command | Does |
|---|---|
| `/ctx` | context-window breakdown: what's actually eating tokens (pi-ctx-info) |
| `/draft <text>` | rewrite rough text into a proper agent prompt — off-transcript; Accept / Copy / Tweak / Deny |
| `/side-question <text>` | get an answer using full session context without polluting the transcript |
| `/stash` / `/stash-list` | park a half-written draft message, restore later (pi-stash) |
| `/edit-turn` | re-edit or remove an earlier user turn in place (pi-edit-session-in-place) |
| `/copy-message` / `/copy-user` | copy raw session text without terminal formatting |
| `/todos` | view the persistent todo list (survives compaction) |
| `/cwd` | show/change working dir safely mid-session (worktrees, monorepos) |
| `/mcp` / `/mcp-auth` | MCP gateway: list/search connected services, authenticate one |
| `/ponytail-review` | run ponytail's audit on demand (see "Ponytail watch" below) |
| `/fitch-setup` / `… verify` | kit installer / read-only drift report |
| `/github-open-issues-prs` | open issues+PRs across Fitch's repos (his, not yours) |

## Agent-facing (no keys — the model uses them)

- `apply_edits` — atomic exact-match edits, plan-first multi-file changes
- `todo_list` — nested persistent tasks; survives long sessions + compaction
- `change_dir` — safe mid-session cd into worktrees/subprojects
- `calculator` — deterministic math instead of model estimation
- tool-duration — model sees how long slow tool calls took (passive)
- browser tools (pi-agent-browser-native) — real-browser QA, screenshots, authed flows

## Skills (auto-load on task match — no invocation needed)

| Skill | Fires when |
|---|---|
| verification-before-completion | about to claim done / commit / PR — forces fresh evidence first |
| deslop | cleaning AI diff noise / ceremonial tests out of a change |
| ux-review | reviewing user-visible flows (completion, recovery, truthfulness) |
| thermo-nuclear-code-quality-review | big or structurally risky diffs |
| tdd | test-first work is explicitly requested |
| dogfood | exploratory QA via real browser/terminal |
| diagram-creation | editable D2 diagrams with rendered previews |
| ask-clarifying-questions | ambiguity that materially changes scope/safety |
| pi-extension-development | building/debugging pi extensions |
| propose-then-ship-pi | rank one repo improvement, stop, then ship it |
| bro | (manual) plain-language rewrite, zero jargon |

## Settings changed (2026-08-27 walkthrough)

settings.json:
- `steeringMode: "all"` — intercom steers inject after any tool call
- `retry` 5 × 120s provider timeout — flaky-route resilience
- `compaction` reserve 64k / keep-recent 40k (Fitch's profile: threshold = window − reserve)
- `defaultThinkingLevel: "high"` (was medium)
- `defaultProjectTrust: "ask"` + `subagents.projectTrust.childRuns: "inherit"` —
  subagents follow saved trust.json decisions, never blanket-approve project resources
- reviewer pin: gpt-5.6-sol @ **xhigh**; AGENTS.md gate = PR-ready, loop until
  "no blocking findings" (+ reviewer-security for risky changes)
- AGENTS.md has Fitch's `baseline` working-agreement block (managed markers)

models.json (Fitch's 320k/64k/40k policy — compact at ~256k with ~60k runway):
- `contextWindow: 320000` on claude-fable-5(-1), claude-opus-5, claude-sonnet-5,
  gpt-5.6-sol, kimi-k3, glm-5p2, deepseek-v4-pro, minimax-m3
- qwen3p7-max LEFT at 262144 (real window < 320k — overriding up would move the failure)
- why: workos.com/blog/coding-agent-context-window-compaction-settings
- backups: models.json.bak-20260827, mcp.json.bak-20260825

mcp.json: added github (bearer via `!gh auth token` — GitHub MCP has no DCR),
notion, linear, granola, cloudflare-docs/-ai-gateway/-observability, datadog.
mcp-datadog extension retired to backup-mcp-datadog-20260825/.

Agent Browser: npm CLI at 0.35.1 (kit manifest baseline 0.34.0 is stale — tell Fitch;
his github catalog entry should also document the bearer pattern)

## Ponytail watch (how to tell it's hurting)

Ponytail injects persistent "reuse / delete / smallest root-cause fix" pressure.
Watch your **reviewer findings** for these new patterns:

- diffs deleting or "simplifying" code that wasn't in scope
- contorted reuse of a near-fit helper instead of a clean small abstraction
- workers under-delivering vs the task spec with "simplified" as the reason
- reviewer loops that churn on minimalism instead of correctness

If findings cluster there: `/ponytail-review` on the diff shows what it would
flag — if its flags consistently miss your taste, disable it:
`pi config` (toggle ponytail off) or remove the package. Zero state, fully reversible.

## Manage

- Cloudflare-routed Anthropic models fail with "credentials … expired/not found"? Cause is a
  stale Anthropic SDK profile in `~/.config/anthropic/` (`ant auth status` shows it) — the SDK
  auto-loads it because pi passes `apiKey: null` for header-auth gateways. Fix: `rm -r
  ~/.config/anthropic` (Claude Code auth is separate, in keychain). Fallback if that dir
  must stay: `~/work/pawprint/scripts/patch-pi-anthropic-gateway` (idempotent, redo after `pi update`)
- `pi config` — enable/disable any extension, skill, prompt, theme (Tab = project-local)
- `pi remove <source>` — uninstall a package
- MCP auth: `/mcp-auth <server>` per service. Exception: `github` uses your gh CLI token
  automatically (`auth: bearer` + `!gh auth token` in mcp.json) — no /mcp-auth needed.
  (GitHub's MCP server doesn't do OAuth dynamic client registration — bearer is the fix.)

## Parked

- **Images in workflows** (revisit ~2026-09-01): whether to use vision more;
  if yes, revisit `images.autoResize: false` + the excluded `anthropic-image-guard`
  (needed together — guard protects Claude routes from oversized-image API errors)
  and `terminal.imageWidthCells`. Parked 2026-08-27.
