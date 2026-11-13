#!/usr/bin/env fish
# Regression: pi runs on Homebrew's node in every shell and directory, while
# mise's tools (node here) stay ahead of Homebrew's for the shell and for every
# command pi runs, across repeated cd + prompt hooks, in fish and zsh.
#
# Run:  fish tests/mise-path-precedence.fish
#
# Installs the repo with the real setup.sh into a fake HOME under
# .artifacts/mise-path-test/ (also checking the guarded config.fish Homebrew
# migration), then starts real fish with its full config lifecycle in that HOME:
# conf.d/brew.fish, Homebrew's vendor mise activation, config.fish. Installed
# mise toolchains (MISE_DATA_DIR) and Homebrew's node are read-only inputs. The
# fake Pi prints its runtime and the node its child processes get. The fixture
# project pins a third installed node so every hook rebuilds mise's PATH
# section. No installs, no writes outside .artifacts.

set -g ROOT (realpath (status filename)/../..)
set -g TEST_TMP $ROOT/.artifacts/mise-path-test
set -g FHOME $TEST_TMP/home
set -g FIXTURE $FHOME/project
set -g BREW_NODE /opt/homebrew/opt/node/bin/node
set -g FAILED

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

if not test -x $BREW_NODE
    echo "FAIL - Homebrew node missing at $BREW_NODE (brew install node)" >&2
    exit 1
end
set -g BREW_EXEC (realpath $BREW_NODE)
set -g BREW_V ($BREW_NODE -v)

rm -rf $TEST_TMP
mkdir -p $FHOME/.config/fish $FIXTURE

# --- setup.sh: install + guarded config.fish migration -------------------

set -l brew_block 'if test -x /opt/homebrew/bin/brew' \
    '    eval (/opt/homebrew/bin/brew shellenv)' \
    'else if test -x /usr/local/bin/brew' \
    '    eval (/usr/local/bin/brew shellenv)' \
    end
set -l cfg $FHOME/.config/fish/config.fish
printf '%s\n' $brew_block '' 'set -g fixture_marker kept' >$cfg
printf '# tail without newline' >>$cfg
cp $cfg $TEST_TMP/config.fish.orig
tail -n +6 $cfg >$TEST_TMP/config.fish.want

env HOME=$FHOME $ROOT/setup.sh --dry-run >$TEST_TMP/setup-dry.out 2>&1
expect "setup --dry-run ran" $status 0
expect "dry run leaves config.fish untouched" (cmp -s $cfg $TEST_TMP/config.fish.orig; echo $status) 0

env HOME=$FHOME $ROOT/setup.sh >$TEST_TMP/setup.out 2>&1
expect "setup ran" $status 0
expect "config.fish lost exactly the Homebrew block" (cmp -s $cfg $TEST_TMP/config.fish.want; echo $status) 0
set -l baks $cfg.bak-dotfiles-*
expect "config.fish backed up once" (count $baks) 1
expect "backup is the original" (cmp -s $baks[1] $TEST_TMP/config.fish.orig; echo $status) 0
expect "config.fish mode kept" (stat -f %Lp $cfg) (stat -f %Lp $TEST_TMP/config.fish.orig)

env HOME=$FHOME $ROOT/setup.sh --check >$TEST_TMP/setup-check.out 2>&1
expect "setup --check passes after setup" $status 0
env HOME=$FHOME $ROOT/setup.sh >$TEST_TMP/setup2.out 2>&1
expect "setup rerun ok" $status 0
set -l baks $cfg.bak-dotfiles-*
expect "rerun makes no second backup" (count $baks) 1
expect "rerun leaves config.fish alone" (cmp -s $cfg $TEST_TMP/config.fish.want; echo $status) 0

# Altered block: left byte-identical, warned, and --check fails.
set -l h2 $TEST_TMP/home-altered
mkdir -p $h2/.config/fish
printf '%s\n' $brew_block[1] '    # local tweak' $brew_block[2..5] 'set -g x 1' >$h2/.config/fish/config.fish
cp $h2/.config/fish/config.fish $TEST_TMP/altered.orig
set -l out (env HOME=$h2 $ROOT/setup.sh 2>&1)
expect "altered: config.fish untouched" (cmp -s $h2/.config/fish/config.fish $TEST_TMP/altered.orig; echo $status) 0
expect "altered: warns" (string match -q '*unexpected form; remove it by hand*' -- $out; echo $status) 0
env HOME=$h2 $ROOT/setup.sh --check >/dev/null 2>&1
expect "altered: --check fails" $status 1

# --- fixtures: fake Pi at the pinned version, an unrelated utility --------

set -l pin (cat $FHOME/.local/share/pi-runtime/version)
set -l pibin $FHOME/.local/share/pi-runtime/$pin/node_modules/.bin
mkdir -p $pibin
printf '%s\n' \
    'let child = "none";' \
    'try { child = require("child_process").execFileSync("node", ["-p", "process.version"], { encoding: "utf8" }).trim(); } catch {}' \
    'console.log(`pi:${process.execPath}|${process.version}|child:${child}|args:${JSON.stringify(process.argv.slice(2))}`);' >$pibin/pi
printf '#!/bin/sh\necho util-ok\n' >$FHOME/.local/bin/hello-util
chmod +x $FHOME/.local/bin/hello-util

# The ceiling keeps mise from loading the real ~/.config/mise from an ancestor dir.
set -g MISE_ENV MISE_DATA_DIR=$HOME/.local/share/mise MISE_TRUSTED_CONFIG_PATHS=$FIXTURE:$FHOME/.config/mise/config.toml MISE_CEILING_PATHS=$TEST_TMP \
    MISE_NOT_FOUND_AUTO_INSTALL=false MISE_AUTO_INSTALL=false
set -l home_node v(env HOME=$FHOME $MISE_ENV mise -C $FHOME current node)
set -l fixture_node
for v in (ls $HOME/.local/share/mise/installs/node | string match -r '^\d+\.\d+\.\d+$')
    if test "v$v" != "$home_node" -a "v$v" != "$BREW_V"
        set fixture_node $v
        break
    end
end
if not set -q fixture_node[1]
    echo "FAIL - need an installed node besides $home_node and $BREW_V for the fixture" >&2
    exit 1
end
printf '[tools]\nnode = "%s"\n' $fixture_node >$FIXTURE/.mise.toml
set -l pi_want "pi:$BREW_EXEC|$BREW_V|child:v$fixture_node"

# --- probes ---------------------------------------------------------------

# fish: full config lifecycle. zsh: mirrors ~/.zprofile (brew) + ~/.zshrc.
# Both start in the fake HOME, below the mise ceiling.
printf '%s\n' \
    'cd $HOME; emit fish_prompt' \
    'printf "home-node:%s\n" (node -v)' \
    'printf "brew:%s|%s\n" (command -s brew) $HOMEBREW_PREFIX' \
    'printf "infopath:%s\n" "$INFOPATH"' \
    'printf "util:%s\n" (hello-util)' \
    'printf "updater:%s\n" (command -s pi-update)' \
    'for cycle in 1 2 3' \
    '    cd $FIXTURE' \
    '    emit fish_prompt; emit fish_prompt' \
    '    printf "which:%s\n" (command -s pi)' \
    '    printf "node:%s\n" (node -v)' \
    '    set -l m (contains -i -- (path dirname (command -s node)) $PATH)' \
    '    set -l l (contains -i -- $HOME/.local/bin $PATH)' \
    '    test $m -lt $l; and echo mise-before-local-bin' \
    '    pi "a b" \'$x\'' \
    '    sh -c "pi nested"' \
    '    printf "child-fish-node:%s\n" (fish -c "node -v")' \
    '    cd $HOME' \
    '    emit fish_prompt' \
    '    printf "which:%s\n" (command -s pi)' \
    '    printf "home-node:%s\n" (node -v)' \
    'end' \
    'cd $FIXTURE; emit fish_prompt' \
    'printf "npm-node:%s\n" (npm exec -c "node -v")' >$TEST_TMP/probe.fish

printf '%s\n' \
    'eval "$(/opt/homebrew/bin/brew shellenv)"' \
    'cd $HOME' \
    'eval "$(mise activate zsh)"' \
    'export PATH="$HOME/.local/bin:$PATH"' \
    'for cycle in 1 2 3; do' \
    '    cd $FIXTURE' \
    '    _mise_hook_precmd; _mise_hook_precmd' \
    '    print "which:$(command -v pi)"' \
    '    print "node:$(node -v)"' \
    '    pi "a b" '\''$x'\''' \
    '    sh -c "pi nested"' \
    '    cd $HOME' \
    '    _mise_hook_precmd' \
    '    print "which:$(command -v pi)"' \
    'done' >$TEST_TMP/probe.zsh

# System-only PATH, as launchd gives a login shell: ~/.local/bin is not preset.
set -l base_env HOME=$FHOME USER=$USER TERM=dumb FIXTURE=$FIXTURE $MISE_ENV \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin

set -l args_want '["a b","$x"]'
for shell in fish zsh
    set -l out $TEST_TMP/$shell.out
    switch $shell
        case fish
            env -i $base_env /bin/sh -c 'cd "$HOME" && exec /opt/homebrew/bin/fish -i "$0"' $TEST_TMP/probe.fish >$out 2>&1
        case zsh
            env -i $base_env /bin/sh -c 'cd "$HOME" && exec /bin/zsh -f "$0"' $TEST_TMP/probe.zsh >$out 2>&1
    end
    expect "$shell probe ran" $status 0
    expect "$shell: pi is the ~/.local/bin launcher on all 6 hook checks" (grep -c "^which:$FHOME/.local/bin/pi\$" $out) 6
    expect "$shell: fixture node v$fixture_node active on all 3 cycles" (grep -c "^node:v$fixture_node\$" $out) 3
    expect "$shell: pi runs on Homebrew node, its children on the project node, args intact" \
        (grep -cF "$pi_want|args:$args_want" $out) 3
    expect "$shell: pi started by a child process behaves the same" (grep -cF "$pi_want|args:[\"nested\"]" $out) 3
end

set -l out $TEST_TMP/fish.out
expect "fish: home dir gets mise's global node $home_node, not Homebrew's" (grep -c "^home-node:$home_node\$" $out) 4
expect "fish: child fish in the project keeps the project node" (grep -c "^child-fish-node:v$fixture_node\$" $out) 3
expect "fish: project npm runs on the project node" (grep -c "^npm-node:v$fixture_node\$" $out) 1
expect "fish: brew still on PATH with its prefix" (grep -c '^brew:/opt/homebrew/bin/brew|/opt/homebrew$' $out) 1
expect "fish: Homebrew info dir on INFOPATH" (grep -c '^infopath:/opt/homebrew/share/info' $out) 1
expect "fish: unrelated ~/.local/bin utility still runs" (grep -c '^util:util-ok$' $out) 1
expect "fish: pi-update found from a clean PATH" (grep -c "^updater:$FHOME/.local/bin/pi-update\$" $out) 1
expect "fish: project's mise tools stay ahead of ~/.local/bin" (grep -c '^mise-before-local-bin$' $out) 3

# Fresh, mise-less environment (launchd, herdr): Homebrew node, no child node.
set -l out (env -i HOME=$FHOME PATH=/usr/bin:/bin $FHOME/.local/bin/pi fresh 2>&1)
expect "fresh env: pi runs on Homebrew node" "$out" "pi:$BREW_EXEC|$BREW_V|child:none|args:[\"fresh\"]"

# Launcher refusals name the fix.
mv $pibin $pibin.off
set -l out (env -i HOME=$FHOME PATH=/usr/bin:/bin $FHOME/.local/bin/pi 2>&1)
expect "missing install: exit 1 with fix" "$status|$out" "1|pi: Pi $pin is not installed; run: pi-update $pin"
mv $pibin.off $pibin
set -l vfile $FHOME/.local/share/pi-runtime/version
for bad in '' '../x' '1.0/../..'
    printf '%s\n' $bad >$vfile
    set -l out (env -i HOME=$FHOME PATH=/usr/bin:/bin $FHOME/.local/bin/pi 2>&1)
    expect "bad pin '$bad': exit 1 with fix" "$status|$out" "1|pi: no valid version in $FHOME/.local/share/pi-runtime/version; run: pi-update"
end

echo
if test (count $FAILED) -gt 0
    echo (count $FAILED)" check(s) failed"
    exit 1
end
echo "all checks passed"
