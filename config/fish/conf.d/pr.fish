# pr-prep fish completion (pr-prep itself: ~/.local/bin/pr-prep, source ~/work/pi/pr-review).
# PR numbers come from pr-watch's cache — the same state.json `pr-prep` (no args)
# lists — never from gh. Lines are "<number>\t<repo> <title>": fish shows the part
# after the tab as the completion's description.

function __pr_prep_review_prs -d "PRs awaiting my review, from pr-watch's cache"
    set -l dir $HOME/.local/state/pr-watch
    test -n "$PR_WATCH_STATE_DIR"; and set dir $PR_WATCH_STATE_DIR  # empty = unset, like bash's ${VAR:-default}
    jq -r '.needs_review[] | "\(.number)\t\(.repo) \(.title)"' $dir/state.json 2>/dev/null
end

function __pr_prep_worktrees -d "pr-<n> worktrees of ~/work/workos → n"
    git -C $HOME/work/workos worktree list --porcelain 2>/dev/null | string replace -rf '^worktree .*/pr-(\d+)$' '$1'
end

# pr-prep <TAB> → review queue; pr-prep --clean <TAB> → existing pr-<n> worktrees
complete -c pr-prep -f -n 'not __fish_seen_argument -l clean' -a '(__pr_prep_review_prs)'
complete -c pr-prep -f -n '__fish_seen_argument -l clean' -a '(__pr_prep_worktrees)'

complete -c pr-prep -l open -d 'Open the worktree in VS Code when done'
complete -c pr-prep -l clean -d 'Remove the pr-<n> worktree pr-prep created (+ its branch)'
complete -c pr-prep -l merged -d 'With --clean: sweep every worktree whose PR is merged/closed'
complete -c pr-prep -l dry-run -d 'Print the git/rush plan, mutate nothing'
complete -c pr-prep -l repo -rf -a '(__fish_complete_directories)' -d 'Monorepo checkout (default ~/work/workos)'
complete -c pr-prep -l no-build -d 'Skip the dependency build'
complete -c pr-prep -l json -d 'No <pr>: print the raw needs_review array'
complete -c pr-prep -s h -l help -d 'Show help'
