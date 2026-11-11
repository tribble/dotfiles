# PR REVIEW
```
pr-review                  what's waiting (Ctrl+click the URL)
pr-review <n>              open it: VS Code for a repo in ws.json (workos, infra), else the browser
pr-checkout --clean <n>    afterwards, for workos worktrees (~9 GB each)
```

Own PR: `pr-review <n>` too. VS Code only for a repo in `ws.json`; others (pawprint included) open in the browser. For VS Code on an unmapped repo: `code <worktree>`. Leave a note for the agent that owns it: select the lines, `ctrl+alt+n`, type the note.
## pr-review
| Command | Does |
|---|---|
| `pr-review --web <n>` | the browser, even when the repo is checked out |
| `pr-review --dry-run <n>` | print the decision + commands, run nothing |
| `pr-review <TAB>` | PR numbers from the queue (also `pr-checkout`; `--clean <TAB>` = worktrees) |
| `<n>` | a bare number (queue lookup), `owner/repo#n`, or the PR URL |
## pr-checkout
| Command | Does |
|---|---|
| `pr-checkout <n>` | worktree + rush install + build the touched projects' deps |
| `pr-checkout --no-build <n>` | worktree + rush install only |
| `pr-checkout --clean <n>` | remove the worktree it created (+ its branch); refuses hand-made ones |
| `pr-checkout --clean --merged` | sweep every one it created whose PR is merged/closed |
| VS Code trust prompt | Manage Workspace Trust → Add Folder → `~/work/workos-worktrees`, once |
## pr-note
| Command | Does |
|---|---|
| `ctrl+alt+n` (VS Code) | the agent tracking the PR (`pr-watch tracked`), else the one working in that checkout; never a guess |
| `pr-note --here --dry-run …` | print that routing (`to`, `resolvedBy`), send nothing |
## pr-watch
| Command | Does |
|---|---|
| `pr-watch status` / `tracked` | the cache / which agent each PR steers |
| `pr-watch track owner/repo#N --agent <intercom-id>` | agents register their own PRs; re-track only when the session UUID changes (a resumed session keeps its ID; a replacement session gets a new one) |
| `launchctl kickstart -k gui/$(id -u)/com.tribble.pr-watch` | restart the poller |
