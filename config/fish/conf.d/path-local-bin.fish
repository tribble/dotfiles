# ~/.local/bin ahead of mise's tool dirs, so ~/.local/bin/pi (the Node 24 wrapper)
# beats mise's own pi. Must run after Homebrew's vendor_conf.d/mise-activate.fish
# (conf.d snippets run in filename order across dirs): mise keeps PATH entries
# added after activation in front (activate_aggressive = false).
fish_add_path --path --move ~/.local/bin
