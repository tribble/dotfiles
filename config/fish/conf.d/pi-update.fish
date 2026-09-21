# pi-update — update pi to the latest release.
# pi is a mise global tool (npm: backend, pinned in ~/.config/mise/config.toml)
# so the same pi runs in every project dir regardless of the project's node pin.
# `pi update` cannot move that pin; this can. Running sessions stay on the old
# version until restarted.
function pi-update -d "update pi (mise global tool) to latest"
    mise use -g npm:@earendil-works/pi-coding-agent@latest
    and pi --version
end
