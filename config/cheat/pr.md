# PR REVIEW
```
pr-review                  what's waiting (Ctrl+click the URL)
pr-review <n>              open it: VS Code (workos/infra) or the browser
pr-checkout --clean <n>    afterwards, for workos worktrees (~9 GB each)
```

Own PR: `pr-review --nvim <n>` (the agent's `open_pr_review` opens it for you) · in VS Code: select, `ctrl+alt+n`, type the note.
Keys in the nvim viewer: `?`.
## pr-review
| Command | Does |
|---|---|
| `pr-review --web <n>` | the browser, even when the repo is checked out |
| `pr-review --nvim <n>` | own PR in octo.nvim, any repo (herdr tab; `\pc` sends a note) |
| `pr-review --dry-run <n>` | print the decision + commands, run nothing |
| `pr-review <TAB>` | PR numbers from the queue (also `pr-checkout`; `--clean <TAB>` = worktrees) |
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
| `ctrl+alt+n` (VS Code) | the agent that opened the PR, else the one in that checkout; never a guess |
| `pr-note --here --dry-run …` | print that routing (`to`, `resolvedBy`), send nothing |
