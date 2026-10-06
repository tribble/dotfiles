# Agent guidance

Personal dotfiles repo — read README.md first.

Runnable checks live in `tests/` (`fish tests/<name>.fish`).

## Rules

- Starting a new independent change: `git fetch` and inspect local/remote
  divergence before choosing the branch base — a local checkout may carry
  unpushed commits unrelated to your task that would ride into the branch.
- Fix tool behavior in the tool's own config before writing shell glue: check
  the tool-manager's native settings (e.g. mise `[env] _.path`) before adding
  per-shell functions or wrappers.
- Test PATH or tool-resolution changes through the real hook lifecycle — cd
  into a pinned project dir, fire the prompt hooks, check child-process
  launches — not just at shell startup. Extend
  `tests/mise-path-precedence.fish` rather than building one-off probes.
- Shipped means three copies agree: local `main` == `origin/main`, and live
  files == repo per `./setup.sh --check`. If another process committed to
  `main` mid-task, merge; never rewrite or reorder commits you didn't author.
