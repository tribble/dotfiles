# fish completion for pr-review and pr-checkout (~/.local/bin, source ~/work/pi/pr-review).
# PR numbers come from pr-watch's cache — the same state.json `pr-review` (no args)
# lists — never from gh. Lines are "<number>\t<repo> <title>": fish shows the part
# after the tab as the completion's description.

function __pr_review_prs -d "PRs awaiting my review, from pr-watch's cache"
    set -l dir $HOME/.local/state/pr-watch
    test -n "$PR_WATCH_STATE_DIR"; and set dir $PR_WATCH_STATE_DIR  # empty = unset, like bash's ${VAR:-default}
    jq -r '.needs_review[] | "\(.number)\t\(.repo) \(.title)"' $dir/state.json 2>/dev/null
end

function __pr_checkout_worktrees -d "pr-<n> worktrees of ~/work/workos → n"
    git -C $HOME/work/workos worktree list --porcelain 2>/dev/null | string replace -rf '^worktree .*/pr-(\d+)$' '$1'
end

# pr-review <TAB> → review queue
complete -c pr-review -f -a '(__pr_review_prs)'
complete -c pr-review -l web -d 'The browser even when a local checkout exists'
complete -c pr-review -l nvim -d 'The diff in octo.nvim, in a new herdr tab (own PRs; any repo)'
complete -c pr-review -l coordinator -x -d 'With --nvim: intercom session ID that \pc notes go to'
complete -c pr-review -l no-focus -d 'With --nvim: open the tab in the background'
complete -c pr-review -l dry-run -d 'Print the decision and the commands, run nothing'
complete -c pr-review -l json -d 'No <pr>: print the raw needs_review array'
complete -c pr-review -s h -l help -d 'Show help'

# pr-checkout <TAB> → review queue; pr-checkout --clean <TAB> → existing pr-<n> worktrees
complete -c pr-checkout -f -n 'not __fish_seen_argument -l clean' -a '(__pr_review_prs)'
complete -c pr-checkout -f -n '__fish_seen_argument -l clean' -a '(__pr_checkout_worktrees)'
complete -c pr-checkout -l clean -d 'Remove the pr-<n> worktree pr-checkout created (+ its branch)'
complete -c pr-checkout -l merged -d 'With --clean: sweep every worktree whose PR is merged/closed'
complete -c pr-checkout -l dry-run -d 'Print the git/rush plan, mutate nothing'
complete -c pr-checkout -l repo -rf -a '(__fish_complete_directories)' -d 'Monorepo checkout (default ~/work/workos)'
complete -c pr-checkout -l no-build -d 'Skip the dependency build'
complete -c pr-checkout -s h -l help -d 'Show help'
