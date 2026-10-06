#!/usr/bin/env fish
# Regression: the tracked global mise config must keep ~/.local/bin ahead of
# mise's tool dirs across repeated cd + prompt hooks, in fish and zsh, via the
# native [env] _.path setting. Baseline config (no [env]) fails: after the
# first hook in a project dir, mise's own npm pi launcher beats ~/.local/bin/pi.
#
# Run:  fish tests/mise-path-precedence.fish
#
# Real mise activation against the tracked config/mise/config.toml (via
# MISE_GLOBAL_CONFIG_FILE) with the real $HOME, read-only: installed
# toolchains and the ~/.local/bin/pi wrapper are inputs. The fixture project
# under .artifacts/mise-path-test/ pins a different installed node so every
# hook rebuilds mise's PATH section; the node-version check proves the
# toolchain actually switched. No installs, no writes outside .artifacts.

set -g ROOT (realpath (status filename)/../..)
set -g TEST_TMP $ROOT/.artifacts/mise-path-test
set -g FIXTURE $TEST_TMP/project
set -g FAILED

rm -rf $TEST_TMP
mkdir -p $FIXTURE $TEST_TMP/mise-config

set -g BASE_ENV HOME=$HOME USER=$USER \
    PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin" \
    MISE_GLOBAL_CONFIG_FILE=$ROOT/config/mise/config.toml \
    MISE_CONFIG_DIR=$TEST_TMP/mise-config \
    MISE_TRUSTED_CONFIG_PATHS=$FIXTURE \
    MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false

set -l current (env $BASE_ENV mise current node)
set -l fixture_node
for v in (ls $HOME/.local/share/mise/installs/node | string match -r '^\d+\.\d+\.\d+$')
    if test "$v" != "$current"
        set fixture_node $v
        break
    end
end
if not set -q fixture_node[1]
    echo "FAIL - need a second installed node version besides $current for the fixture" >&2
    exit 1
end
printf '[tools]\nnode = "%s"\n' $fixture_node >$FIXTURE/.mise.toml

# --- probes (mirror the live shell setup: mise-activate.fish / zshrc) ------

printf '%s\n' \
    'cd $HOME' \
    'mise activate fish | source' \
    'fish_add_path --path --move ~/.local/bin' \
    'for cycle in 1 2 3' \
    '    cd $FIXTURE' \
    '    emit fish_prompt; emit fish_prompt' \
    '    printf "pi:%s\n" (command -s pi)' \
    '    printf "node:%s\n" (node -p process.version)' \
    '    cd $HOME' \
    '    emit fish_prompt' \
    '    printf "pi:%s\n" (command -s pi)' \
    'end' >$TEST_TMP/probe.fish

printf '%s\n' \
    'cd $HOME' \
    'eval "$(mise activate zsh)"' \
    'export PATH="$HOME/.local/bin:$PATH"' \
    'for cycle in 1 2 3; do' \
    '    cd $FIXTURE' \
    '    _mise_hook_precmd; _mise_hook_precmd' \
    '    print "pi:$(command -v pi)"' \
    '    print "node:$(node -p process.version)"' \
    '    cd $HOME' \
    '    _mise_hook_precmd' \
    '    print "pi:$(command -v pi)"' \
    'done' >$TEST_TMP/probe.zsh

# --- helpers -------------------------------------------------------------

function expect -a desc actual expected
    if test "$actual" = "$expected"
        echo "ok   - $desc"
    else
        echo "FAIL - $desc"
        echo "       expected: $expected"
        echo "       actual:   $actual"
        set -ga FAILED $desc
    end
end

# --- run ------------------------------------------------------------------

for shell in fish zsh
    set -l out $TEST_TMP/$shell.out
    switch $shell
        case fish
            env $BASE_ENV FIXTURE=$FIXTURE /opt/homebrew/bin/fish --no-config $TEST_TMP/probe.fish >$out 2>&1
        case zsh
            env $BASE_ENV FIXTURE=$FIXTURE /bin/zsh -f $TEST_TMP/probe.zsh >$out 2>&1
    end
    expect "$shell probe ran" $status 0
    expect "$shell: pi stays the ~/.local/bin wrapper on all 6 hook checks" (grep -c "^pi:$HOME/.local/bin/pi\$" $out) 6
    expect "$shell: probe emitted 6 pi checks" (grep -c '^pi:' $out) 6
    expect "$shell: fixture node $fixture_node active on all 3 cycles" (grep -c "^node:v$fixture_node\$" $out) 3
end

echo
if test (count $FAILED) -gt 0
    echo (count $FAILED)" check(s) failed"
    exit 1
end
echo "all checks passed"
