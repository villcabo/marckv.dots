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
