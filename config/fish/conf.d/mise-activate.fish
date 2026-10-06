# Replaces Homebrew's vendor_conf.d/mise-activate.fish: same basename, and fish
# sources user conf.d before vendor conf.d and only the first file per name.
# Activates mise, then moves ~/.local/bin in front of mise's tool dirs so
# ~/.local/bin/pi (the Node 24 wrapper) beats mise's own pi. The one-time move
# establishes initial precedence; the global mise [env] _.path setting
# (config/mise/config.toml) maintains it across directory and prompt hooks.
if test "$MISE_FISH_AUTO_ACTIVATE" != 0
    /opt/homebrew/opt/mise/bin/mise activate fish | source
end
fish_add_path --path --move ~/.local/bin
