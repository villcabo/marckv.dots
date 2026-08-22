#!/usr/bin/env bats
# di — list images, and say which ones you could delete.

load '../helpers/common'

# di is host-wide, so it runs out of the workspace root rather than a fixture.

# --- help -------------------------------------------------------------------

@test "di --help shows usage" {
    run in_dir "$WORK" 'di --help'
    [[ "$output" == *"USAGE"* ]]
}

@test "di --help explains the USED column" {
    run in_dir "$WORK" 'di --help'
    [[ "$output" == *"deletion candidate"* ]]
}

@test "di --help explains what dangling means" {
    run in_dir "$WORK" 'di --help'
    [[ "$output" == *"lost its tag"* ]]
}

# --- the table --------------------------------------------------------------

@test "di names its scope" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"docker images"* ]]
}

@test "di follows the classic docker images column order" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"REPOSITORY  TAG  "* || "$output" == *"REPOSITORY"*"TAG"*"IMAGE ID"*"CREATED"*"SIZE"*"USED"* ]]
}

@test "di shows the repository" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"nginx"* ]]
}

@test "di shows the tag" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"18-alpine"* ]]
}

@test "di shows the image id" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"aa11bb22cc33"* ]]
}

@test "di shows the size" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"1.37GB"* ]]
}

# A long repository is left whole — a cut name cannot be pasted anywhere.
@test "di does not truncate a long repository" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"quay.io/example/very-long-image-name"* ]]
}

@test "di compacts CREATED by default" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"3w"* ]]
}

@test "di -t switches CREATED to a date" {
    run in_dir "$WORK" 'di -t'
    [[ "$output" == *"2026-07-08"* ]]
}

# --- the USED column --------------------------------------------------------
#
# The count matters more than the fact: 2 containers on one image says
# something a checkmark would not.

@test "di shows how many containers use an image" {
    run in_dir "$WORK" 'di nginx'
    [[ "$output" == *" 2"* ]]
}

@test "di marks an image nothing is using" {
    run in_dir "$WORK" 'di postgres'
    [[ "$output" == *"—"* ]]
}

# --- dangling ---------------------------------------------------------------
#
# `docker images` HIDES dangling images by default — the first version of this
# command therefore reported zero of them while fifteen sat on the disk. They
# are fetched with a second, explicit query.

@test "di includes dangling images" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"dd11ee22ff33"* ]]
}

# <none>:<none> reads like a bug rather than a state.
@test "di labels dangling images instead of showing <none>" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"<dangling>"* ]]
}

@test "di shows no raw <none> repository" {
    run in_dir "$WORK" 'di'
    [[ "$output" != *"<none>"* ]]
}

@test "di counts dangling images in the footer" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"2 dangling"* ]]
}

@test "di counts unused images in the footer" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"unused"* ]]
}

# --- the reclaimable figure -------------------------------------------------
#
# It comes from `docker system df`, never from adding sizes up: images share
# layers, so summing the dangling and unused ones on the author's machine gives
# 10.32GB where the truth is 4.72GB.
#
# That call is also the single most expensive thing di can do — 333ms against
# the ~130ms of the whole rest of the command — so it is behind -s. The tests
# below check both halves of that: the figure appears when asked for, and the
# call is NOT MADE when it is not. The second half needs the shim's call
# counter; asserting only that the output lacks the figure would pass just as
# happily if docker were invoked and the answer discarded.

# df_calls <command> → how many times the command reached `docker system df`
df_calls() {
    rm -f "$WORK/system-df-calls"
    in_dir "$WORK" "$1" >/dev/null 2>&1
    if [[ -f "$WORK/system-df-calls" ]]; then
        wc -c < "$WORK/system-df-calls" | tr -d ' '
    else
        printf '0'
    fi
}

@test "di -s reports what is actually reclaimable" {
    run in_dir "$WORK" 'di -s'
    [[ "$output" == *"4.721GB"* ]]
}

@test "di -s labels the reclaimable figure" {
    run in_dir "$WORK" 'di -s'
    [[ "$output" == *"reclaimable"* ]]
}

@test "di omits the reclaimable figure without -s" {
    run in_dir "$WORK" 'di'
    [[ "$output" != *"reclaimable"* ]]
}

@test "di still counts dangling and unused without -s" {
    run in_dir "$WORK" 'di'
    [[ "$output" == *"2 dangling"* ]]
}

@test "di does not reach docker system df without -s" {
    run df_calls 'di'
    [ "$output" = "0" ]
}

# The counterpart, so the test above cannot pass by the call being impossible.
@test "di -s does reach docker system df" {
    run df_calls 'di -s'
    [ "$output" = "1" ]
}

@test "di -s asks for it only once" {
    run df_calls 'di -s'
    [ "$output" = "1" ]
}

# -s is about the footer, and the footer belongs to the unfiltered view only.
@test "di -s on a filtered view skips the call too" {
    run df_calls 'di -s nginx'
    [ "$output" = "0" ]
}

@test "di -us skips the call, -u having removed the footer" {
    run df_calls 'di -us'
    [ "$output" = "0" ]
}

@test "di -s clusters with other short flags" {
    run in_dir "$WORK" 'di -st'
    [[ "$output" == *"4.721GB"* ]]
}

@test "di --help documents -s" {
    run in_dir "$WORK" 'di --help'
    [[ "$output" == *"-s"* ]]
}

@test "di --help says the reclaimable figure costs" {
    run in_dir "$WORK" 'di --help'
    [[ "$output" == *"300ms"* ]]
}

# A total that describes the machine, printed under rows that do not, reads as
# a lie about those rows.
@test "di omits the footer on a filtered view" {
    run in_dir "$WORK" 'di nginx'
    [[ "$output" != *"reclaimable"* ]]
}

@test "di omits the footer for -u" {
    run in_dir "$WORK" 'di -u'
    [[ "$output" != *"reclaimable"* ]]
}

# --- filters ----------------------------------------------------------------

@test "di -d shows only dangling images" {
    run in_dir "$WORK" 'di -d'
    [[ "$output" == *"<dangling>"* ]]
}

@test "di -d excludes tagged images" {
    run in_dir "$WORK" 'di -d'
    [[ "$output" != *"nginx"* ]]
}

@test "di -u shows an image nothing uses" {
    run in_dir "$WORK" 'di -u'
    [[ "$output" == *"postgres"* ]]
}

@test "di -u excludes images in use" {
    run in_dir "$WORK" 'di -u'
    [[ "$output" != *"nginx"* ]]
}

@test "di filters on a pattern" {
    run in_dir "$WORK" 'di nginx'
    [[ "$output" == *"nginx"* ]]
}

@test "di excludes what the pattern missed" {
    run in_dir "$WORK" 'di nginx'
    [[ "$output" != *"postgres"* ]]
}

# The pattern matches repository:tag, so a tag alone finds it.
@test "di matches against repository:tag" {
    run in_dir "$WORK" 'di 18-alpine'
    [[ "$output" == *"postgres"* ]]
}

@test "di says what it filtered on" {
    run in_dir "$WORK" 'di nginx'
    [[ "$output" == *"filter:"* ]]
}

# --- errors -----------------------------------------------------------------

@test "di exits 1 on an unknown flag" {
    run rc_of "$WORK" 'di -Z'
    [ "$output" = "1" ]
}

@test "di renders a table when nothing matches" {
    run in_dir "$WORK" 'di zzzz'
    [[ "$output" == *"nothing to show"* ]]
}

# --- completion -------------------------------------------------------------

@test "di completes repository:tag pairs" {
    run complete_in "$WORK" 1 di ''
    [[ "$output" == *"nginx:alpine"* ]]
}

@test "di offers -u" {
    run complete_in "$WORK" 1 di '-'
    [[ "$output" == *"-u"* ]]
}

@test "di offers -d" {
    run complete_in "$WORK" 1 di '-'
    [[ "$output" == *"-d"* ]]
}

@test "di does not offer dangling images as completions" {
    run complete_in "$WORK" 1 di ''
    [[ "$output" != *"<none>"* ]]
}
