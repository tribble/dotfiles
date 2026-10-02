#!/usr/bin/env fish
# Runnable check for local/bin/pi-update.
#
# Run:  fish tests/pi-update.fish
#
# Uses a fake HOME and stubbed npm / mise install+version steps — never touches
# the real pi install or the real ~/work/dotfiles. Only `mise config set` runs
# the real mise (native single-key edit), scoped by the function's own
# MISE_TRUSTED_CONFIG_PATHS to the fixture file. Fixtures and logs live in
# .artifacts/pi-update-test/ (gitignored) and are recreated each run.

set -g ROOT (realpath (status filename)/../..)
set -g TEST_TMP $ROOT/.artifacts/pi-update-test
set -g STUB_BIN $TEST_TMP/bin
set -g SCRIPT $ROOT/local/bin/pi-update
set -g BASE_PATH (string join : $PATH)
set -g REAL_MISE (command -v mise)
set -g FAILED

if not set -q REAL_MISE[1]
    echo "mise not found on PATH" >&2
    exit 1
end

rm -rf $TEST_TMP
mkdir -p $STUB_BIN

# --- stubs -------------------------------------------------------------

# sh stubs: no fish startup, so no vendor_conf.d mise-activate noise.
printf '%s\n' '#!/bin/sh' \
    'if [ -n "$STUB_NPM_FAIL" ]; then echo "npm ERR! registry unreachable" >&2; exit 1; fi' \
    'printf "%s\n" "$STUB_NPM_VERSION"' >$STUB_BIN/npm

printf '%s\n' '#!/bin/sh' \
    'case "$1" in' \
    '  use)' \
    '    if [ -n "$STUB_MISE_USE_FAIL" ]; then echo "mise ERROR: install failed" >&2; exit 1; fi' \
    '    echo "$*" >> "$STUB_LOG"' \
    '    echo "mise: installed $3"' \
    '    ;;' \
    '  x)' \
    '    if [ -n "$STUB_MISE_X_FAIL" ]; then echo "mise ERROR: exec failed" >&2; exit 1; fi' \
    '    echo "pi $STUB_NPM_VERSION"' \
    '    ;;' \
    '  config)' \
    '    exec "$REAL_MISE" "$@"' \
    '    ;;' \
    'esac' >$STUB_BIN/mise

chmod +x $STUB_BIN/npm $STUB_BIN/mise

# --- helpers -----------------------------------------------------------

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

function expect_match -a desc pattern text
    if string match -q -- "*$pattern*" $text
        echo "ok   - $desc"
    else
        echo "FAIL - $desc (missing: $pattern)"
        echo "       output: $text"
        set -ga FAILED $desc
    end
end

function mkhome -a name
    set -l h $TEST_TMP/$name
    mkdir -p $h/work/dotfiles/config/mise
    set -l repo $h/work/dotfiles
    git -c init.defaultBranch=main init -q $repo
    git -C $repo config user.name test
    git -C $repo config user.email test@test
    git -C $repo config commit.gpgsign false
    printf '[tools]\nnode = "24"\n"npm:@earendil-works/pi-coding-agent" = "0.87.1"\n' >$repo/config/mise/config.toml
    echo base >$repo/other.txt
    git -C $repo add config/mise/config.toml other.txt
    git -C $repo commit -qm init
    echo $h
end

function run_pi_update -a home
    env HOME=$home \
        XDG_CONFIG_HOME=$home/.config XDG_DATA_HOME=$home/.local/share \
        XDG_STATE_HOME=$home/.local/state XDG_CACHE_HOME=$home/.cache \
        PATH="$STUB_BIN:$BASE_PATH" REAL_MISE=$REAL_MISE \
        STUB_LOG=$home/stub.log $argv[2..-1] \
        fish --no-config $SCRIPT
end

# --- s1: update + pin-only local commit, unrelated work preserved ------

set -l h (mkhome s1)
set -l repo $h/work/dotfiles
echo staged >$repo/staged.txt
git -C $repo add staged.txt
echo dirty >>$repo/other.txt
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s1 exit ok" $st 0
expect_match "s1 reports new version" "pi 9.9.9" "$out"
expect "s1 installed exact npm latest" (cat $h/stub.log) "use -g npm:@earendil-works/pi-coding-agent@9.9.9"
expect "s1 pin synced" (grep -c '"npm:@earendil-works/pi-coding-agent" = "9.9.9"' $repo/config/mise/config.toml) 1
expect "s1 other keys kept" (grep -c 'node = "24"' $repo/config/mise/config.toml) 1
expect "s1 commit holds only the pin file" (git -C $repo diff-tree --no-commit-id --name-only -r HEAD) "config/mise/config.toml"
expect_match "s1 commit message" "9.9.9" (git -C $repo log -1 --pretty=%s)
expect_match "s1 says local, not pushed" "not pushed" "$out"
expect "s1 staged file kept staged" (git -C $repo status --porcelain -- staged.txt) "A  staged.txt"
expect "s1 unstaged file kept dirty" (git -C $repo status --porcelain -- other.txt) " M other.txt"

# --- s2: rerun is a no-op, no empty commit -----------------------------

set -l head1 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s2 exit ok" $st 0
expect "s2 no new commit" (git -C $repo rev-parse HEAD) $head1
expect_match "s2 says nothing to commit" "nothing to commit" "$out"

# --- s3: dirty target rejected before install ---------------------------

set -l h (mkhome s3)
set -l repo $h/work/dotfiles
echo local-edit >>$repo/config/mise/config.toml
set -l head0 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s3 exit nonzero" $st 1
expect_match "s3 explains" "uncommitted changes" "$out"
expect "s3 install never ran" (test -f $h/stub.log; echo $status) 1
expect "s3 no commit" (git -C $repo rev-parse HEAD) $head0
expect "s3 edit untouched" (git -C $repo status --porcelain -- config/mise/config.toml) " M config/mise/config.toml"

# --- s4: npm failure → nonzero, no install, no commit -------------------

set -l h (mkhome s4)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h STUB_NPM_FAIL=1 2>&1)
set -l st $status
expect "s4 exit nonzero" $st 1
expect "s4 install never ran" (test -f $h/stub.log; echo $status) 1
expect "s4 no commit" (git -C $repo rev-parse HEAD) $head0
expect "s4 pin unchanged" (grep -c '0.87.1' $repo/config/mise/config.toml) 1

# --- s5: install failure → nonzero, pin untouched -----------------------

set -l h (mkhome s5)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 STUB_MISE_USE_FAIL=1 2>&1)
set -l st $status
expect "s5 exit nonzero" $st 1
expect "s5 pin unchanged" (grep -c '0.87.1' $repo/config/mise/config.toml) 1
expect "s5 no commit" (git -C $repo rev-parse HEAD) $head0

# --- s6: version-report failure → nonzero, pin untouched ----------------

set -l h (mkhome s6)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 STUB_MISE_X_FAIL=1 2>&1)
set -l st $status
expect "s6 exit nonzero" $st 1
expect "s6 pin unchanged" (grep -c '0.87.1' $repo/config/mise/config.toml) 1
expect "s6 no commit" (git -C $repo rev-parse HEAD) $head0

# --- s7: config-write failure → distinct save-failure, no commit --------

set -l h (mkhome s7)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
chmod 0444 $repo/config/mise/config.toml
chmod 0555 $repo/config/mise
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
chmod 0755 $repo/config/mise
chmod 0644 $repo/config/mise/config.toml
expect "s7 exit nonzero" $st 1
expect_match "s7 says installed but save failed" "installed, but" "$out"
expect "s7 no commit" (git -C $repo rev-parse HEAD) $head0

# --- s8: commit failure → distinct failure, edit left uncommitted -------

set -l h (mkhome s8)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
printf '#!/bin/sh\nexit 1\n' >$repo/.git/hooks/pre-commit
chmod +x $repo/.git/hooks/pre-commit
set -l out (run_pi_update $h STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s8 exit nonzero" $st 1
expect_match "s8 says commit failed" "commit" "$out"
expect "s8 no success message" (string match -q -- "*committed locally*" $out; echo $status) 1
expect "s8 no commit" (git -C $repo rev-parse HEAD) $head0
expect "s8 pin edit left uncommitted" (git -C $repo status --porcelain -- config/mise/config.toml) " M config/mise/config.toml"

# --- result -------------------------------------------------------------

echo
if test (count $FAILED) -gt 0
    echo (count $FAILED)" check(s) failed"
    exit 1
end
echo "all checks passed"
