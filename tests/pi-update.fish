#!/usr/bin/env fish
# Runnable check for local/bin/pi-update.
#
# Run:  fish tests/pi-update.fish
#
# Uses a fake HOME and a fake Homebrew prefix (HOMEBREW_PREFIX) whose npm and
# node are stubs — never touches the real pi install, the network or the real
# ~/work/dotfiles. Fixtures and logs live in .artifacts/pi-update-test/
# (gitignored) and are recreated each run.

set -g ROOT (realpath (status filename)/../..)
set -g TEST_TMP $ROOT/.artifacts/pi-update-test
set -g BREW $TEST_TMP/brew
set -g NODEBIN $BREW/opt/node/bin
set -g SCRIPT $ROOT/local/bin/pi-update
set -g BASE_PATH (string join : $PATH)
set -g PIN local/share/pi-runtime/version
set -g FAILED

rm -rf $TEST_TMP
mkdir -p $NODEBIN

# --- stubs -------------------------------------------------------------

# npm: `view` prints the stub latest; `install --prefix P … pkg@V` writes a pi
# that reports V (or $STUB_PI_REPORTS) and exits $STUB_PI_EXIT; `audit signatures` passes or fails.
printf '%s\n' '#!/bin/sh' \
    'echo "npm $1 node=$(command -v node)" >> "$STUB_LOG"' \
    'case "$1" in' \
    '  view)' \
    '    if [ -n "$STUB_NPM_FAIL" ]; then echo "npm ERR! registry unreachable" >&2; exit 1; fi' \
    '    printf "%s\n" "$STUB_NPM_VERSION" ;;' \
    '  install)' \
    '    prefix=$3; for a; do spec=$a; done' \
    '    echo "install $prefix $spec" >> "$STUB_LOG"' \
    '    mkdir -p "$prefix/node_modules/.bin"' \
    '    if [ -n "$STUB_INSTALL_FAIL" ]; then echo "npm ERR! 404" >&2; exit 1; fi' \
    '    printf "#!/bin/sh\necho %s\nexit %s\n" "${STUB_PI_REPORTS:-${spec##*@}}" "${STUB_PI_EXIT:-0}" > "$prefix/node_modules/.bin/pi" ;;' \
    '  audit)' \
    '    if [ -n "$STUB_AUDIT_FAIL" ]; then echo "1 package has an invalid registry signature" >&2; exit 1; fi ;;' \
    'esac' >$NODEBIN/npm

# node: runs the given pi script, as Homebrew node would run cli.js.
printf '%s\n' '#!/bin/sh' 'exec /bin/sh "$@"' >$NODEBIN/node

chmod +x $NODEBIN/npm $NODEBIN/node

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

# Fake home: dotfiles repo + remote pinned at 0.87.1, and a working 0.87.1 install.
function mkhome -a name
    set -l h $TEST_TMP/$name
    set -l repo $h/work/dotfiles
    mkdir -p $repo/(dirname $PIN)
    git -c init.defaultBranch=main init -q $repo
    git -C $repo config user.name test
    git -C $repo config user.email test@test
    git -C $repo config commit.gpgsign false
    echo 0.87.1 >$repo/$PIN
    echo base >$repo/other.txt
    git -C $repo add $PIN other.txt
    git -C $repo commit -qm init
    git -c init.defaultBranch=main init --bare -q $h/remote.git
    git -C $repo remote add origin $h/remote.git
    git -C $repo push -qu origin main
    set -l rt $h/.local/share/pi-runtime
    mkdir -p $rt/0.87.1/node_modules/.bin
    printf '#!/bin/sh\necho 0.87.1\n' >$rt/0.87.1/node_modules/.bin/pi
    echo 0.87.1 >$rt/version
    echo $h
end

# run_pi_update HOME VERSION-ARG-or-"" [VAR=value …]
function run_pi_update -a home ver
    set -l args
    test -n "$ver"; and set args $ver
    env HOME=$home HOMEBREW_PREFIX=$BREW \
        PATH="$BASE_PATH" STUB_LOG=$home/stub.log $argv[3..-1] \
        fish --no-config $SCRIPT $args
end

# The working 0.87.1 install and its pin survive a failed update.
function expect_current_kept -a tag h
    set -l rt $h/.local/share/pi-runtime
    expect "$tag live pin unchanged" (cat $rt/version) 0.87.1
    expect "$tag current install still runs" (sh $rt/0.87.1/node_modules/.bin/pi) 0.87.1
    expect "$tag no new install dir" (test -e $rt/9.9.9; echo $status) 1
    expect "$tag temp dir removed" (count $rt/.install-*) 0
    expect "$tag repo pin unchanged" (cat $h/work/dotfiles/$PIN) 0.87.1
end

# --- s1: update + pin-only local commit, unrelated work preserved ------

set -l h (mkhome s1)
set -l repo $h/work/dotfiles
set -l rt $h/.local/share/pi-runtime
echo staged >$repo/staged.txt
git -C $repo add staged.txt
echo dirty >>$repo/other.txt
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s1 exit ok" $st 0
expect_match "s1 reports new version" "pi 9.9.9" "$out"
expect_match "s1 installed exact npm latest" "@earendil-works/pi-coding-agent@9.9.9" (grep '^install ' $h/stub.log)
expect "s1 npm runs on Homebrew node" (grep -c "node=$NODEBIN/node\$" $h/stub.log) (grep -c '^npm ' $h/stub.log)
expect "s1 signatures audited" (grep -c '^npm audit' $h/stub.log) 1
expect "s1 live pin moved" (cat $rt/version) 9.9.9
expect "s1 new install runs" (sh $rt/9.9.9/node_modules/.bin/pi) 9.9.9
expect "s1 old install kept for running sessions" (sh $rt/0.87.1/node_modules/.bin/pi) 0.87.1
expect "s1 temp dir renamed away" (count $rt/.install-*) 0
expect "s1 repo pin synced" (cat $repo/$PIN) 9.9.9
expect "s1 commit holds only the pin file" (git -C $repo diff-tree --no-commit-id --name-only -r HEAD) $PIN
expect_match "s1 commit message" "9.9.9" (git -C $repo log -1 --pretty=%s)
expect_match "s1 says installed and committed locally" "installed; dotfiles pin committed locally" "$out"
expect "s1 remote pin advanced" (git --git-dir=$h/remote.git show main:$PIN) 9.9.9
expect "s1 remote matches local commit" (git --git-dir=$h/remote.git rev-parse main) (git -C $repo rev-parse HEAD)
expect "s1 staged file kept staged" (git -C $repo status --porcelain -- staged.txt) "A  staged.txt"
expect "s1 unstaged file kept dirty" (git -C $repo status --porcelain -- other.txt) " M other.txt"

# --- s2: rerun is a no-op: no reinstall, no empty commit ----------------

set -l head1 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s2 exit ok" $st 0
expect "s2 no reinstall" (grep -c '^install ' $h/stub.log) 1
expect "s2 no new commit" (git -C $repo rev-parse HEAD) $head1
expect_match "s2 says already installed and pinned" "already installed and pinned" "$out"

# --- publish rejection and same-version retry --------------------------

printf '#!/bin/sh\nexit 1\n' >$h/remote.git/hooks/pre-receive
chmod +x $h/remote.git/hooks/pre-receive
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.10 2>&1)
set -l st $status
set -l pending (git -C $repo rev-parse HEAD)
expect "push rejection exits nonzero" $st 1
expect_match "push rejection explains installed state" "pi 9.9.10 installed and pinned locally, but pushing failed" "$out"
expect_match "push rejection requires resolving Git error" "resolve the Git error above, then retry" "$out"
expect_match "push rejection offers rerun" "retry with pi-update" "$out"
expect_match "push rejection offers exact push" "git -C $repo push" "$out"
expect "push rejection keeps remote unchanged" (git --git-dir=$h/remote.git rev-parse main) $head1
expect "push rejection keeps new local commit" (git -C $repo rev-list --count $head1..HEAD) 1
expect "push rejection keeps pin committed" (git -C $repo status --porcelain -- $PIN) ""
expect "push rejection keeps staged work" (git -C $repo status --porcelain -- staged.txt) "A  staged.txt"
expect "push rejection keeps unstaged work" (git -C $repo status --porcelain -- other.txt) " M other.txt"
rm $h/remote.git/hooks/pre-receive
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.10 2>&1)
set -l st $status
expect "retry exits ok" $st 0
expect "retry creates no new commit" (git -C $repo rev-parse HEAD) $pending
expect "retry publishes pending commit" (git --git-dir=$h/remote.git rev-parse main) $pending

# --- explicit version: no registry lookup -------------------------------

set -l h (mkhome explicit)
set -l out (run_pi_update $h 1.2.3 STUB_NPM_FAIL=1 2>&1)
set -l st $status
expect "explicit exit ok" $st 0
expect "explicit skips npm view" (grep -c '^npm view' $h/stub.log) 0
expect "explicit live pin" (cat $h/.local/share/pi-runtime/version) 1.2.3
expect "explicit repo pin" (cat $h/work/dotfiles/$PIN) 1.2.3

# --- invalid version refused before install -----------------------------

set -l h (mkhome invalid)
set -l out (run_pi_update $h ../x 2>&1)
set -l st $status
expect "invalid exit nonzero" $st 1
expect_match "invalid explains" "is not a version" "$out"
expect "invalid npm never ran" (test -f $h/stub.log; echo $status) 1
expect_current_kept invalid $h

# --- s3: dirty target rejected before install ---------------------------

set -l h (mkhome s3)
set -l repo $h/work/dotfiles
echo local-edit >>$repo/$PIN
set -l head0 (git -C $repo rev-parse HEAD)
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s3 exit nonzero" $st 1
expect_match "s3 explains" "uncommitted changes" "$out"
expect "s3 npm never ran" (test -f $h/stub.log; echo $status) 1
expect "s3 no commit" (git -C $repo rev-parse HEAD) $head0
expect "s3 edit untouched" (git -C $repo status --porcelain -- $PIN) " M $PIN"

# --- s4: npm view failure → nonzero, no install, no commit -------------

set -l h (mkhome s4)
set -l head0 (git -C $h/work/dotfiles rev-parse HEAD)
set -l out (run_pi_update $h "" STUB_NPM_FAIL=1 2>&1)
set -l st $status
expect "s4 exit nonzero" $st 1
expect "s4 install never ran" (grep -c '^install ' $h/stub.log) 0
expect "s4 no commit" (git -C $h/work/dotfiles rev-parse HEAD) $head0
expect_current_kept s4 $h

# --- s5: install / signature / version failures keep the working pi ----

for case in install:STUB_INSTALL_FAIL=1 audit:STUB_AUDIT_FAIL=1 version:STUB_PI_REPORTS=0.0.1 exit:STUB_PI_EXIT=42
    set -l tag s5-(string split -f1 : $case)
    set -l h (mkhome $tag)
    set -l head0 (git -C $h/work/dotfiles rev-parse HEAD)
    set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 (string split -f2 : $case) 2>&1)
    set -l st $status
    expect "$tag exit nonzero" $st 1
    expect_match "$tag says current pi unchanged" "current pi is unchanged" "$out"
    expect "$tag no commit" (git -C $h/work/dotfiles rev-parse HEAD) $head0
    expect_current_kept $tag $h
end

# Existing install that prints the version but exits nonzero is not pinned.
set -l h (mkhome s5-existing-exit)
set -l rt $h/.local/share/pi-runtime
mkdir -p $rt/9.9.9/node_modules/.bin
printf '#!/bin/sh\necho 9.9.9\nexit 42\n' >$rt/9.9.9/node_modules/.bin/pi
set -l head0 (git -C $h/work/dotfiles rev-parse HEAD)
set -l out (run_pi_update $h 9.9.9 2>&1)
set -l st $status
expect "s5-existing-exit exit nonzero" $st 1
expect_match "s5-existing-exit says current pi unchanged" "current pi is unchanged" "$out"
expect "s5-existing-exit npm never ran" (test -f $h/stub.log; echo $status) 1
expect "s5-existing-exit live pin unchanged" (cat $rt/version) 0.87.1
expect "s5-existing-exit repo pin unchanged" (cat $h/work/dotfiles/$PIN) 0.87.1
expect "s5-existing-exit no commit" (git -C $h/work/dotfiles rev-parse HEAD) $head0

# --- s7: repo pin write failure → distinct save-failure, no commit ------

set -l h (mkhome s7)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
chmod 0444 $repo/$PIN
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
chmod 0644 $repo/$PIN
expect "s7 exit nonzero" $st 1
expect_match "s7 says installed but save failed" "installed, but" "$out"
expect "s7 no commit" (git -C $repo rev-parse HEAD) $head0

# --- s8: commit failure → distinct failure, edit left uncommitted -------

set -l h (mkhome s8)
set -l repo $h/work/dotfiles
set -l head0 (git -C $repo rev-parse HEAD)
printf '#!/bin/sh\nexit 1\n' >$repo/.git/hooks/pre-commit
chmod +x $repo/.git/hooks/pre-commit
set -l out (run_pi_update $h "" STUB_NPM_VERSION=9.9.9 2>&1)
set -l st $status
expect "s8 exit nonzero" $st 1
expect_match "s8 says commit failed" "commit" "$out"
expect "s8 no success message" (string match -q -- "*committed locally*" $out; echo $status) 1
expect "s8 no commit" (git -C $repo rev-parse HEAD) $head0
expect "s8 pin edit left uncommitted" (git -C $repo status --porcelain -- $PIN) " M $PIN"

# --- real npm: lifecycle scripts never run; audit gates package code ----
# Homebrew's real npm installs a local package whose lifecycle scripts and
# cli each leave a marker. The wrapper swaps only the registry spec for the
# tarball, so pi-update's own install flags reach real npm; audit is faked.

set -l rb $TEST_TMP/real-brew/opt/node/bin
set -l pkgdir $TEST_TMP/fixture-pkg
set -g MARK $TEST_TMP/marks
mkdir -p $rb $pkgdir $MARK
ln -s /opt/homebrew/opt/node/bin/node $rb/node
printf '%s\n' '{"name":"@earendil-works/pi-coding-agent","version":"9.9.9","bin":{"pi":"cli.js"},' \
    '"scripts":{"preinstall":"node hook.js","install":"node hook.js","postinstall":"node hook.js"}}' >$pkgdir/package.json
echo 'require("fs").writeFileSync(process.env.FIXTURE_MARK + "/lifecycle", "ran")' >$pkgdir/hook.js
printf '%s\n' 'require("fs").writeFileSync(process.env.FIXTURE_MARK + "/cli", "ran")' 'console.log("9.9.9")' >$pkgdir/cli.js
touch $TEST_TMP/npmrc-user $TEST_TMP/npmrc-global
set -l npm_env npm_config_cache=$TEST_TMP/npm-cache npm_config_userconfig=$TEST_TMP/npmrc-user \
    npm_config_globalconfig=$TEST_TMP/npmrc-global npm_config_update_notifier=false
env PATH=/opt/homebrew/opt/node/bin:$BASE_PATH $npm_env /opt/homebrew/opt/node/bin/npm pack --silent \
    --pack-destination $TEST_TMP $pkgdir >/dev/null
set -l tgz $TEST_TMP/earendil-works-pi-coding-agent-9.9.9.tgz
printf '%s\n' '#!/bin/sh' \
    'cmd=$1; shift' \
    'case "$cmd" in' \
    '  audit) if [ -n "$FIXTURE_AUDIT_FAIL" ]; then echo "fixture: invalid registry signature" >&2; exit 1; fi ;;' \
    '  install)' \
    '    n=$#; i=0' \
    '    for a; do i=$((i + 1)); if [ "$i" = "$n" ]; then set -- "$@" "$FIXTURE_TGZ"; else set -- "$@" "$a"; fi; done' \
    '    shift "$n"' \
    '    exec /opt/homebrew/opt/node/bin/npm install --offline "$@" ;;' \
    '  *) exit 2 ;;' \
    'esac' >$rb/npm
chmod +x $rb/npm

set -l h (mkhome real-audit-fail)
set -l out (run_pi_update $h 9.9.9 HOMEBREW_PREFIX=$TEST_TMP/real-brew FIXTURE_TGZ=$tgz FIXTURE_MARK=$MARK \
    FIXTURE_AUDIT_FAIL=1 $npm_env 2>&1)
set -l st $status
expect "real-audit-fail exit nonzero" $st 1
expect "real-audit-fail: no lifecycle script ran" (test -e $MARK/lifecycle; echo $status) 1
expect "real-audit-fail: package cli never ran" (test -e $MARK/cli; echo $status) 1
expect_current_kept real-audit-fail $h

set -l h (mkhome real-ok)
set -l out (run_pi_update $h 9.9.9 HOMEBREW_PREFIX=$TEST_TMP/real-brew FIXTURE_TGZ=$tgz FIXTURE_MARK=$MARK \
    $npm_env 2>&1)
set -l st $status
expect "real-ok exit ok" $st 0
expect "real-ok: no lifecycle script ran" (test -e $MARK/lifecycle; echo $status) 1
expect "real-ok: cli ran only for the version check" (test -e $MARK/cli; echo $status) 0
expect "real-ok: live pin moved" (cat $h/.local/share/pi-runtime/version) 9.9.9

# --- result -------------------------------------------------------------

echo
if test (count $FAILED) -gt 0
    echo (count $FAILED)" check(s) failed"
    exit 1
end
echo "all checks passed"
