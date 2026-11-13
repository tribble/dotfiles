# ~/.local/bin (pi, pi-update, other user tools) and Homebrew. conf.d runs in
# filename order, so this precedes mise-activate.fish and mise's tools stay
# ahead of both, as in zsh. Homebrew init used to sit in config.fish, which
# runs after conf.d and put Homebrew first.
fish_add_path --path ~/.local/bin
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if test -x /usr/local/bin/brew
    eval (/usr/local/bin/brew shellenv)
end
