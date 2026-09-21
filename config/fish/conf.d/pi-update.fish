# pi-update — update pi to the latest release.
# pi is a mise global tool (npm: backend, pinned in ~/.config/mise/config.toml)
# so the same pi runs in every project dir regardless of the project's node pin.
# `pi update` cannot move that pin; this can. Pins the exact version npm calls
# latest: mise's own `@latest` hides releases younger than minimum_release_age
# and can install one version while a stale `latest` symlink runs another.
# Running sessions stay on the old version until restarted.
function pi-update -d "update pi (mise global tool) to npm's latest"
    set -l v (npm view @earendil-works/pi-coding-agent version)
    or return
    mise use -g npm:@earendil-works/pi-coding-agent@$v
    and pi --version
end
