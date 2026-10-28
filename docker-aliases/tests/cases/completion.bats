#!/usr/bin/env bats
# Completion for every command, in whichever shell DA_SHELL names.
#
# bash is driven exactly as bash drives it. zsh cannot be — see the note in
# helpers/common.bash — so compadd and _files are stubbed. That covers the
# branching and the data it feeds on; compsys wiring stays a manual check.

load '../helpers/common'

# --- dcup -------------------------------------------------------------------

@test "dcup completes services on a bare word" {
    run complete_in "$F/basic" 1 dcup ''
    [[ "$output" == *"api"* ]]
}

@test "dcup offers -r after a dash" {
    run complete_in "$F/basic" 1 dcup '-'
    [[ "$output" == *"-r"* ]]
}

@test "dcup offers -P after a dash" {
    run complete_in "$F/basic" 1 dcup '-'
    [[ "$output" == *"-P"* ]]
}

@test "dcup never offers a -y flag" {
    run complete_in "$F/basic" 1 dcup '-'
    [[ "$output" != *"-y"* ]]
}

@test "dcup -f completes yml files" {
    run complete_in "$F/multifile" 2 dcup -f ''
    [[ "$output" == *"base.yml"* || "$output" == *"__files__"* ]]
}

@test "dcup -P completes profiles" {
    run complete_in "$F/profiles" 2 dcup -P ''
    [[ "$output" == *"debug"* ]]
}

# A half-typed command already naming a profile must offer that profile's
# services, or TAB describes a different project than the command would act on.
@test "dcup services follow the -P already typed" {
    run complete_in "$F/profiles" 3 dcup -P debug ''
    [[ "$output" == *"debugger"* ]]
}

# --- dclt -------------------------------------------------------------------

@test "dclt completes services" {
    run complete_in "$F/basic" 1 dclt ''
    [[ "$output" == *"worker"* ]]
}

@test "dclt offers -o" {
    run complete_in "$F/basic" 1 dclt '-'
    [[ "$output" == *"-o"* ]]
}

@test "dclt offers -s" {
    run complete_in "$F/basic" 1 dclt '-'
    [[ "$output" == *"-s"* ]]
}

@test "dclt -n suggests line counts" {
    run complete_in "$F/basic" 2 dclt -n ''
    [[ "$output" == *"500"* ]]
}

@test "dclt -n suggests 'all'" {
    run complete_in "$F/basic" 2 dclt -n ''
    [[ "$output" == *"all"* ]]
}

@test "dclt -s suggests durations" {
    run complete_in "$F/basic" 2 dclt -s ''
    [[ "$output" == *"10m"* ]]
}

# --- dcdown -----------------------------------------------------------------

@test "dcdown completes services" {
    run complete_in "$F/volumes" 1 dcdown ''
    [[ "$output" == *"cache"* ]]
}

@test "dcdown offers -v" {
    run complete_in "$F/volumes" 1 dcdown '-'
    [[ "$output" == *"-v"* ]]
}

@test "dcdown offers -O" {
    run complete_in "$F/volumes" 1 dcdown '-'
    [[ "$output" == *"-O"* ]]
}

# --- dcx --------------------------------------------------------------------

@test "dcx completes services first" {
    run complete_in "$F/multimatch" 1 dcx ''
    [[ "$output" == *"api-worker"* ]]
}

@test "dcx offers commands once the pattern is given" {
    run complete_in "$F/multimatch" 2 dcx api ''
    [[ "$output" == *"bash"* ]]
}

@test "dcx stops offering services after the pattern" {
    run complete_in "$F/multimatch" 2 dcx api ''
    [[ "$output" != *"api-worker"* ]]
}

@test "dcx -u suggests root" {
    run complete_in "$F/multimatch" 2 dcx -u ''
    [[ "$output" == *"root"* ]]
}

# --- dcd --------------------------------------------------------------------

@test "dcd completes containers host-wide" {
    run complete_in "$WORK" 1 dcd ''
    [[ "$output" == *"other-api"* ]]
}

@test "dcd offers -p" {
    run complete_in "$WORK" 1 dcd '-'
    [[ "$output" == *"-p"* ]]
}

@test "dcd offers -i" {
    run complete_in "$WORK" 1 dcd '-'
    [[ "$output" == *"-i"* ]]
}

# --- dcver ------------------------------------------------------------------

@test "dcver completes services" {
    run complete_in "$F/versions" 1 dcver ''
    [[ "$output" == *"dirtyapp"* ]]
}

# --- dver -------------------------------------------------------------------

@test "dver completes containers host-wide" {
    run complete_in "$WORK" 1 dver ''
    [[ "$output" == *"other-api"* ]]
}

# --- profiles ---------------------------------------------------------------
#
# TAB used to offer a narrower list than the command accepted, which is the
# worst of both: it stayed silent about a service that would have worked.

@test "dclt completion offers a service behind a profile" {
    run complete_in "$F/profiles" 1 dclt see
    [[ "$output" == *"seeder"* ]]
}

@test "dcx completion offers a service behind a profile" {
    run complete_in "$F/profiles" 1 dcx debug
    [[ "$output" == *"debugger"* ]]
}

@test "dcdown completion offers a service behind a profile" {
    run complete_in "$F/profiles" 1 dcdown metr
    [[ "$output" == *"metrics"* ]]
}

@test "dcup completion offers a service behind a profile" {
    # dcup narrows its PREVIEW, not what it accepts: it never validates the
    # names it is handed. Completing only the profile-less ones would hide a
    # service `dcup seeder` starts perfectly well.
    run complete_in "$F/profiles" 1 dcup see
    [[ "$output" == *"seeder"* ]]
}

# --- flag parity: parser vs both completions --------------------------------
#
# One test for a whole class of bug. `di` accepted -s and neither completion
# offered it; nobody noticed because di.bats only ever exercised -u and -d.
# Checking one flag at a time would have missed it the same way, so this
# derives the list from the parser and compares all eleven commands at once.
#
# Short clusters (`dcd -pi`) and the `--` separator are not flags a completion
# should offer, so they are dropped rather than special-cased per command.

# Every command, derived from commands/ rather than listed. The first version of
# these tests named the eleven by hand, so the next command to be added would
# have escaped the parity check entirely — which is the exact failure the
# tests exist to prevent, recreated one level up.
all_commands() {
    local f
    for f in "$DA_DIR"/commands/*.sh; do
        f="${f##*/}"; printf '%s\n' "${f%.sh}"
    done
}

flags_of_parser() {   # commands/<x>.sh → one flag per line
    sed -n '/while \[\[ \$# -gt 0 \]\]/,/^[[:space:]]*done/p' "$1" \
        | grep -oE '^[[:space:]]+-[a-zA-Z|-]+\)' \
        | tr -d ' )' | tr '|' '\n' \
        | grep -E '^(-[a-zA-Z]|--[a-z-]+)$' \
        | LC_ALL=C sort -u
}

flags_of_completion() {   # completions/<x>.{bash,zsh} → one flag per line
    # The explicit flag list, not every dash in the file: compgen and compadd
    # take flags of their own and would pollute the comparison.
    { grep -oE 'compgen -W "(-[^"]*)"' "$1" | sed -E 's/compgen -W "//; s/"$//'
      grep -oE 'flags=\((-[^)]*)\)'    "$1" | sed -E 's/flags=\(//; s/\)$//'
    } | tr ' ' '\n' \
      | grep -E '^(-[a-zA-Z]|--[a-z-]+)$' \
      | LC_ALL=C sort -u
}

@test "the flag extractors find something for every command" {
    # The control. Without it, an extractor that silently returns nothing
    # makes every comparison below pass — which is how the bug it is meant to
    # catch would survive the test written to catch it.
    local cmd n
    for cmd in $(all_commands); do
        n=$(flags_of_parser "$DA_DIR/commands/$cmd.sh" | grep -c .)
        [ "$n" -gt 0 ] || { printf 'parser extraction empty: %s\n' "$cmd" >&2; return 1; }
        n=$(flags_of_completion "$DA_DIR/completions/$cmd.bash" | grep -c .)
        [ "$n" -gt 0 ] || { printf 'bash completion extraction empty: %s\n' "$cmd" >&2; return 1; }
        n=$(flags_of_completion "$DA_DIR/completions/$cmd.zsh" | grep -c .)
        [ "$n" -gt 0 ] || { printf 'zsh completion extraction empty: %s\n' "$cmd" >&2; return 1; }
    done
}

@test "every flag the parser accepts is offered by both completions" {
    local cmd missing_bash missing_zsh bad=""
    for cmd in $(all_commands); do
        missing_bash=$(LC_ALL=C comm -23 \
            <(flags_of_parser "$DA_DIR/commands/$cmd.sh") \
            <(flags_of_completion "$DA_DIR/completions/$cmd.bash") | tr '\n' ' ')
        missing_zsh=$(LC_ALL=C comm -23 \
            <(flags_of_parser "$DA_DIR/commands/$cmd.sh") \
            <(flags_of_completion "$DA_DIR/completions/$cmd.zsh") | tr '\n' ' ')
        [ -n "${missing_bash// }" ] && bad+="  $cmd: bash misses $missing_bash"$'\n'
        [ -n "${missing_zsh// }" ]  && bad+="  $cmd: zsh misses $missing_zsh"$'\n'
    done
    [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "no completion offers a flag the parser would reject" {
    # The worse direction of the two: a TAB that promises something the
    # command refuses. dps completes values for -f, -e and -P, which dps does
    # not accept.
    local cmd extra_bash extra_zsh bad=""
    for cmd in $(all_commands); do
        extra_bash=$(LC_ALL=C comm -13 \
            <(flags_of_parser "$DA_DIR/commands/$cmd.sh") \
            <(flags_of_completion "$DA_DIR/completions/$cmd.bash") | tr '\n' ' ')
        extra_zsh=$(LC_ALL=C comm -13 \
            <(flags_of_parser "$DA_DIR/commands/$cmd.sh") \
            <(flags_of_completion "$DA_DIR/completions/$cmd.zsh") | tr '\n' ' ')
        [ -n "${extra_bash// }" ] && bad+="  $cmd: bash offers $extra_bash"$'\n'
        [ -n "${extra_zsh// }" ]  && bad+="  $cmd: zsh offers $extra_zsh"$'\n'
    done
    [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

@test "bash and zsh completions offer the same flags" {
    local cmd d bad=""
    for cmd in $(all_commands); do
        d=$(LC_ALL=C diff \
            <(flags_of_completion "$DA_DIR/completions/$cmd.bash") \
            <(flags_of_completion "$DA_DIR/completions/$cmd.zsh") || true)
        [ -n "$d" ] && bad+="  $cmd:"$'\n'"$d"$'\n'
    done
    [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}

flags_with_values_of_completion() {   # completions/<x>.{bash,zsh} → flags whose VALUE the completion completes
    # The `case "$prev"` / `case "${words[CURRENT-1]}"` arms. A branch here for
    # a flag the parser rejects is dead code that still costs a docker call if
    # somebody types the flag by hand.
    sed -n '/case "\$prev" in/,/esac/p;/case "\${words\[CURRENT-1\]}" in/,/esac/p' "$1" \
        | grep -oE '^[[:space:]]+-[a-zA-Z|-]+\)' \
        | tr -d ' )' | tr '|' '\n' \
        | grep -E '^(-[a-zA-Z]|--[a-z-]+)$' \
        | LC_ALL=C sort -u
}

@test "no completion completes a value for a flag the parser rejects" {
    # dps carried -f, -e and -P branches copied from the compose commands and
    # accepts none of the three. The flag-list tests above cannot see this: the
    # dead branches are in the value-completion case, not in the offered list.
    local cmd extra bad=""
    for cmd in $(all_commands); do
        for sh in bash zsh; do
            extra=$(LC_ALL=C comm -13 \
                <(flags_of_parser "$DA_DIR/commands/$cmd.sh") \
                <(flags_with_values_of_completion "$DA_DIR/completions/$cmd.$sh") | tr '\n' ' ')
            [ -n "${extra// }" ] && bad+="  $cmd ($sh): completes values for $extra"$'\n'
        done
    done
    [ -z "$bad" ] || { printf '%s' "$bad" >&2; return 1; }
}
