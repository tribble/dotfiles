# pi-update — update pi to the latest release.
# pi is a mise global tool (npm: backend, pinned in ~/.config/mise/config.toml)
# so the same pi runs in every project dir regardless of the project's node pin.
# `pi update` cannot move that pin; this can. Pins the exact version npm calls
# latest: mise's own `@latest` hides releases younger than minimum_release_age
# and can install one version while a stale `latest` symlink runs another.
# Running sessions stay on the old version until restarted. `mise x` reports the
# new version: this shell's PATH still holds the old install dir until the next prompt.
# On success the pin is also written into the dotfiles source
# (~/work/dotfiles/config/mise/config.toml) and committed locally — only that
# file, never pushed. Refuses to start when that file has uncommitted changes;
# an install that succeeded but could not be saved says so and returns nonzero.
function pi-update -d "update pi (mise global tool) to npm's latest"
    set -l repo ~/work/dotfiles
    set -l rel config/mise/config.toml
    set -l target $repo/$rel

    if not git -C $repo ls-files --error-unmatch -- $rel >/dev/null 2>&1
        echo "pi-update: $rel is not tracked in $repo; refusing to update" >&2
        return 1
    end
    if test -n "$(git -C $repo status --porcelain -- $rel)"
        echo "pi-update: $rel has uncommitted changes; commit or stash them first" >&2
        return 1
    end

    set -l v (npm view @earendil-works/pi-coding-agent version)
    or return

    mise use -g npm:@earendil-works/pi-coding-agent@$v
    and mise x -- pi --version
    or return

    if not MISE_TRUSTED_CONFIG_PATHS=$target mise config set --file $target 'tools.npm:@earendil-works/pi-coding-agent' $v
        echo "pi-update: pi $v installed, but writing the pin to $target failed" >&2
        return 1
    end
    if git -C $repo diff --quiet -- $rel
        echo "pi-update: dotfiles pin already at $v; nothing to commit"
        return 0
    end
    if git -C $repo commit --quiet --only -m "mise: pin pi $v" -- $rel
        echo "pi-update: dotfiles pin updated to $v and committed locally (not pushed)"
    else
        echo "pi-update: pi $v installed, but committing the dotfiles pin failed; edit left uncommitted" >&2
        return 1
    end
end
