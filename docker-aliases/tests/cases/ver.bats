#!/usr/bin/env bats
# dcver and dver — which build is running.
#
# One file for both: the same question at two scopes.

load '../helpers/common'

# --- properties parsing -----------------------------------------------------
#
# Java .properties escapes ":" and "#" on write, so a timestamp arrives as
# 2024-04-18T16\:56\:45 and reads like a typo if passed through raw.

pv() { lib_call "$F/versions" "_prop_value '$1' '$2'"; }

@test "a plain property value is read" {
    run pv git.branch 'git.branch=main'
    [ "$output" = "main" ]
}

@test "escaped colons are undone" {
    run pv git.commit.time 'git.commit.time=2024-04-18T16\:56\:45-0400'
    [ "$output" = "2024-04-18T16:56:45-0400" ]
}

@test "escaped hashes are undone" {
    run pv git.msg 'git.msg=fix \#136'
    [ "$output" = "fix #136" ]
}

# git.commit.id is a prefix of git.commit.id.abbrev
@test "a key that is a prefix of another does not match it" {
    run pv git.commit.id.abbrev 'git.commit.id=abcdefg1234
git.commit.id.abbrev=7'
    [ "$output" = "7" ]
}

# --- dcver ------------------------------------------------------------------

@test "dcver names its scope" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"compose versions"* ]]
}

@test "dcver reads the version from app.version" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"1.1.0-d3cabc9"* ]]
}

@test "dcver lists a second service" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"2.0.0-aabbccd"* ]]
}

@test "dcver shows the short commit" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"d3cabc9"* ]]
}

@test "dcver shows the branch" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"develop"* ]]
}

# A build made from uncommitted changes cannot be rebuilt from the commit it
# names, so the commit is a hint rather than a fact.
@test "dcver flags a dirty build" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"dirty"* ]]
}

# …and a clean one must NOT be, or the flag stops meaning anything.
@test "dcver does not flag a clean build" {
    run in_dir "$F/versions" 'dcver cleanapp'
    [[ "$output" != *"dirty"* ]]
}

@test "dcver filters on a pattern" {
    run in_dir "$F/versions" 'dcver cleanapp'
    [[ "$output" == *"1 of 1"* ]]
}

@test "dcver states a missing git.properties" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"no git.properties"* ]]
}

@test "dcver counts honestly" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" == *"2 of 3"* ]]
}

# The old dcpr printed the 40-character hash and a merge commit's whole message.
@test "dcver shows no full-length commit hash" {
    run in_dir "$F/versions" 'dcver'
    [[ "$output" != *"d3cabc9876e722"* ]]
}

@test "dcver -r dumps every field" {
    run in_dir "$F/versions" 'dcver -r cleanapp'
    [[ "$output" == *"git.commit.id.abbrev"* ]]
}

@test "dcver -r names the path it found" {
    run in_dir "$F/versions" 'dcver -r cleanapp'
    [[ "$output" == *"/app/resources"* ]]
}

# Raw means raw: the file as it is on disk. The table is where values get
# cleaned up.
@test "dcver -r keeps the file verbatim" {
    run in_dir "$F/versions" 'dcver -r cleanapp'
    [[ "$output" == *'16\:56'* ]]
}

@test "dcver exits 1 on an unknown flag" {
    run rc_of "$F/versions" 'dcver -Z'
    [ "$output" = "1" ]
}

@test "dcver lists what was available when nothing matches" {
    run err_of "$F/versions" 'dcver zzz'
    [[ "$output" == *"available:"* ]]
}

# --- dver -------------------------------------------------------------------

@test "dver names its scope" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"docker versions"* ]]
}

@test "dver shows a versioned container" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"9.9.9-hostwide"* ]]
}

@test "dver shows the project" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"fixture-proj"* ]]
}

@test "dver flags a dirty build" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"dirty"* ]]
}

# Three answers should not be buried under fifteen rows of dashes. They stay
# NAMED in the footer, so the omission is checkable rather than silent.
@test "dver drops unversioned containers from the table" {
    run in_dir "$WORK" 'dver'
    body=$(printf '%s\n' "$output" | grep -v "with no git.properties")
    [[ "$body" != *"plain-box"* ]]
}

@test "dver names the omitted containers in the footer" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"plain-box"* ]]
}

@test "dver says how many it omitted" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"with no git.properties"* ]]
}

@test "dver keeps the header count honest" {
    run in_dir "$WORK" 'dver'
    [[ "$output" == *"1 of 4"* ]]
}

@test "dver -a brings the omitted ones back" {
    run in_dir "$WORK" 'dver -a'
    [[ "$output" == *"plain-box"* ]]
}

@test "dver filters on a pattern" {
    run in_dir "$WORK" 'dver fx-api'
    [[ "$output" == *"9.9.9-hostwide"* ]]
}

@test "dver excludes what the pattern missed" {
    run in_dir "$WORK" 'dver fx-api'
    [[ "$output" != *"other-api"* ]]
}

@test "dver exits 1 on an unknown flag" {
    run rc_of "$WORK" 'dver -Z'
    [ "$output" = "1" ]
}

@test "dver exits 1 when nothing matches" {
    run rc_of "$WORK" 'dver zzzz'
    [ "$output" = "1" ]
}
