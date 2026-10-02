# Replaces Homebrew's vendor_conf.d/mise-activate.fish: same basename, and fish
# sources user conf.d before vendor conf.d and only the first file per name.
# Activates mise, then moves ~/.local/bin in front of mise's tool dirs so
# ~/.local/bin/pi (the Node 24 wrapper) beats mise's own pi. mise keeps PATH
# changes made after activation (activate_aggressive = false); a move made
# before activation is undone.
if test "$MISE_FISH_AUTO_ACTIVATE" != 0
    /opt/homebrew/opt/mise/bin/mise activate fish | source
end
fish_add_path --path --move ~/.local/bin
