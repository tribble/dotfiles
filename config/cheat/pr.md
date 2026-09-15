# PR REVIEW — CHEAT SHEET

`pr-review` is the one front door with three surfaces: `pr-review <n>` = VS Code on
a `pr-checkout` worktree (repo in ws.json) else the browser; `--web` = the browser;
`--nvim` = your OWN PR in a herdr tab: the diff, reviewer comments on it, and `\pc`
notes to the agent that owns the PR (any repo, no checkout).
Others' PRs: `pr-review` → `pr-review <n>` → review → `pr-checkout --clean <n>`.
Own PR: the agent's `open_pr_review` tool opens the tab; or `pr-review --nvim <pr>`;
or `pr-review <n>` + `ctrl+alt+n` in VS Code.

Same content as the in-viewer help float: press `?` inside any review buffer
(diff panes or the changed-files panel), `<leader>?` (`\?`) anywhere, or
`<leader>` + pause for which-key's live popup of every mapping. In the float,
`q` / `Esc` / `CR` closes.

| Key | Action | Key | Action |
|-----|--------|-----|--------|
| **MODES** | *(you never edit in this tool — no insert mode needed)* | | |
| `Esc` | back to normal mode (home base) | `:` | command line |
| `v` `V` `C-v` | select chars / lines / block (only needed to mark lines) | | |
| **MOVING** | | | |
| `h j k l` | left / down / up / right | `w` `b` | word forward / back |
| `gg` `G` | top / bottom of file | `{` `}` | paragraph up / down |
| `C-d` `C-u` | half-page down / up | `%` | jump to matching bracket |
| `/text` `n` `N` | search, then next / prev match | `''` | back to previous spot |
| **READING THE DIFF** | *(left pane = old code, right pane = new code)* | | |
| `C-w w` | cycle between left / right / files panel | | |
| `zo` `zc` `zR` | open fold / close fold / unfold all (`+-- N lines` collapsed hunks) | | |
| `]q` `[q` | next / previous changed file | `]t` `[t` | next / previous comment thread |
| `]u` `[u` | next / previous unviewed file | `\` `Space` | mark file as viewed |
| `\e` `\b` | focus files panel / toggle panel hidden | | |
| `Enter` | (in files panel) open that file's diff | | |
| **SELECTING** | *(only to mark lines for `\pc`)* | | |
| `V` then `j`/`k` | select lines (extend with moves) | `o` | jump cursor to other end |
| `Esc` | cancel the selection | | |
| **THE REVIEW LOOP** | | | |
| `V..` `\pc` | send selected lines + typed note to the agent that owns the PR | | |
| `C-c` | close the review tab | | |
| **WINDOWS / TABS** | | | |
| `C-w =` | equalize splits | `gt` `gT` | next / previous tab |
| `C-w o` | keep only this window | `:q` | close window |
| **HELP** | | | |
| `?` | this card (inside review buffers) | `\?` | this card (anywhere) |
| `\` + pause | which-key: live popup of every mapping | | |
| `:nmap <buffer>` | raw list of buffer-local mappings | | |

Keep in sync with `HELP_TEXT` in `nvim/pr-review.lua` (the float renders
exactly that text).

## pr-review: the queue, and the right surface for a PR

| Command | Does |
|---------|------|
| `pr-review` | the PRs awaiting your review, from pr-watch's cache (`~/.local/state/pr-watch/state.json`; no `gh` call): `  <number>  <repo>  <title>  (<age>[, draft])  <url>` (Ctrl+click the URL in herdr), then `pr-review <number>`. Human-readable stdout; `--json` = the raw `needs_review` array. No state → "is the daemon running? (pr-watch daemon)", exit 1. |
| `pr-review <pr>` (a number, `owner/repo#n`, or the URL) | the PR's repo is checked out (`~/.pi/agent/configs/ws.json` `repos`, origin normalised to `owner/repo`) → `pr-checkout <n> --repo <checkout>` (progress on stderr) then `code <worktree>/monorepo.code-workspace` (or the worktree — infra: no rush.json, so worktree only, no build); any other repo → `open <url>`. Not in the queue (own PR) → one `gh pr view` (per ws.json repo for a bare number); a bare number in several repos → error naming them. One JSON line: `{ok, pr, repo, surface: "vscode"/"web"/"nvim", worktree?, tab_id?, pane_id?}`; a pr-checkout failure propagates its error. |
| `pr-review --web <pr>` / `--dry-run <pr>` | the browser even with a checkout / print the decision + commands (stderr), run nothing |
| `pr-review --nvim [--coordinator <id>] [--no-focus] <pr>` | own PR, any repo: a new tab in this herdr workspace (label `PR #<n>`, env `PR_REVIEW_PR=owner/repo#n`) running `pr-review-nvim` → octo.nvim review layout. An explicit `owner/repo#n`/URL skips queue + ws.json (one `gh pr view`); a bare number resolves via the queue. Coordinator (the intercom session `\pc` notes go to, injected as `PR_REVIEW_COORDINATOR`): `--coordinator` (the `open_pr_review` tool passes its own ID) → `$PR_REVIEW_COORDINATOR` → `~/.config/pr-review/config.json` → `$PI_SESSION_NAME`; none → pr-note routes each note (track.json → agent in the checkout). Needs `HERDR_ENV=1`. `--dry-run` prints the two herdr commands. |
| `pr-review <TAB>` / `pr-checkout <TAB>` / `pr-checkout --clean <TAB>` | fish (`conf.d/pr.fish`): PR numbers with `<repo> <title>` from the same cache / same / `pr-<n>` worktrees of `~/work/workos`; flags with descriptions |

## pr-checkout: PR → worktree (workos: with go-to-definition for VS Code)

| Command | Does |
|---------|------|
| `pr-checkout [--no-build] [--dry-run] <pr>` | reuse/create `~/work/workos-worktrees/pr-<n>` on the PR branch → `rush install` → `rush build --to-except <touched projects>` (deps only, so `@workos-inc/*` imports resolve to `src/*.ts`). JSON on stdout (`worktree` is what pr-review opens), rush output on stderr. A created worktree gets a `pr-checkout.json` marker in its git dir (`.git/worktrees/pr-<n>/`; a reused one never does). `--repo <checkout>` without rush.json (infra): the worktree only, one stderr line, `built: false`. No `<pr>` → usage, exit 2. |
| `pr-checkout --clean [--dry-run] <pr>` | remove `pr-<n>` (~9 GB each) — only if registered + marked + still on that branch + no uncommitted tracked changes (untracked files go with it); `branch -D` only when pr-checkout created the branch. No marker (pre-marker worktrees, hand-made ones) = refuses: `git -C ~/work/workos worktree remove --force <path>` yourself. |
| `pr-checkout --clean --merged [--dry-run]` | sweep every marked `pr-<n>` whose PR is MERGED/CLOSED (`gh`); OPEN → `skipped`, no marker → `unmarked`. One JSON summary with `freed_bytes`. |
| VS Code trust prompt per worktree | Workspaces: Manage Workspace Trust → Add Folder → `~/work/workos-worktrees` (trust inherits) |

## VS Code: selection → the agent that owns the PR

| Key / command | Does |
|---------------|------|
| select code, `ctrl+alt+n`, type note, Enter | user task `Send selection to PR agent` → `pr-note --here --path ${file} --code ${selectedText} --body …`. Select on the RIGHT (new) side of a diff; the file must be saved (the selection is located on disk). Success is silent; a failure reveals the task terminal with the error. |
| `pr-note --here --dry-run --path <file> --code <text> --body t` | print the resolved `{to, toName, resolvedBy, pr, path, start, end, side}` without sending (`to` = the recipient's intercom session ID, `resolvedBy` = which step below won) |
| recipient order | `--to` → pr-watch `~/.local/state/pr-watch/track.json` (`agent_id` of the agent that opened the PR) → the one live intercom session whose `cwd` is the file's git checkout or inside it (`pr-note --list` shows cwds; `subagent-*` dropped when several; still several = error naming them) → `$PR_REVIEW_COORDINATOR` / `~/.config/pr-review/config.json` (overrides, if you want one) → `no agent is working in <root> … start one there (ws / /ws) or pass --to`. Every step yields a session ID; a name given anywhere is resolved to the one live session with exactly that name (`pr-note --resolve <name>` shows it) |
| files | dotfiles `vscode/{tasks,keybindings,settings}.json` → `~/Library/Application Support/Code/User/` via `~/work/dotfiles/setup.sh` |
