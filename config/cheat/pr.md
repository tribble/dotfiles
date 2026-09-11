# PR REVIEW — CHEAT SHEET

For reading your OWN PRs in a herdr tab (`pr-review-open <pr>`): the diff,
reviewer comments on it, and `\pc` notes to the agent that owns the PR. Other
people's PRs get reviewed in the GitHub web UI (`prs` opens your queue).

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

## github auth: ssh → https rewrite (permanent)

Ephemeral (teleport) SSH keys expire mid-session and break GitHub ops. Global
gitconfig rewrites all GitHub SSH URLs to HTTPS (gh token path, keyring-backed):

```
url.https://github.com/.insteadOf = git@github.com:
url.https://github.com/.insteadOf = ssh://git@github.com/
url.git@github.com:workos/.insteadOf = git@github.com:workos/   # work org stays SSH (longest match wins)
```

test: `GIT_SSH_COMMAND=false git ls-remote git@github.com:tribble/pawprint.git`
If everything breaks at once → `gh auth login` re-heals every repo.
