# ws / herdr fish integration
# ws itself lives at ~/.local/bin/ws

function wls -d "List workstreams (ws ls)"
    ws ls $argv
end

function wagents -d "All live herdr agents: name, status, cwd"
    herdr agent list 2>/dev/null | jq -r '.result.agents[] | [(.name // .pane_id), .agent_status, .cwd] | @tsv' | column -ts \t
end

# wblocked lives at ~/.local/bin/wblocked (sh shim) so bash/`!!` get it too.

# --- dynamic completions for herdr itself ---
# The shipped completions (completions/herdr.fish, clap-generated) are static:
# subcommands and flags only. These add live agent/workspace names. Kept here
# so regenerating the shipped file never clobbers them.

function __herdr_agent_names
    herdr agent list 2>/dev/null | jq -r '.result.agents[] | (.name // .pane_id) + "\t" + .agent_status' 2>/dev/null
end

function __herdr_workspace_ids
    herdr workspace list 2>/dev/null | jq -r '.result.workspaces[] | .workspace_id + "\t" + .label' 2>/dev/null
end

# herdr agent <verb> <TAB> -> live agent names (with status as description)
complete -c herdr -n "__fish_seen_subcommand_from agent; and __fish_seen_subcommand_from get read send-keys prompt rename focus wait attach explain" -f -a "(__herdr_agent_names)"

complete -c wblocked -f -a "(__herdr_agent_names)"

# herdr workspace <verb> <TAB> -> workspace ids (with label as description)
complete -c herdr -n "__fish_seen_subcommand_from workspace; and __fish_seen_subcommand_from get focus rename close" -f -a "(__herdr_workspace_ids)"

function kimi -d "pi in kimi-experiment mode (kimi-k3 max + kimi subagents)"
    pi --preset kimi $argv
end

# PR review queue: other people's PRs are reviewed in the GitHub web UI.
# (Own PRs: `pr-review-open <pr>` opens the diff in a herdr tab.)
abbr -a prs 'gh search prs --review-requested=@me --state=open --web'
