#!/usr/bin/env bats
# dps and dcps — listing containers and services.
#
# One file for both: they are the same command at two scopes.

load '../helpers/common'

# --- port compaction --------------------------------------------------------
#
# This is why dps1 and dpsp stopped being necessary. The string below is 76
# characters, of which 9 carry information.

ports() { lib_call "$F/basic" "_compact_ports '$1' '${2:-false}'"; }

@test "unpublished ports are dropped and published ones kept" {
    run ports '8080/tcp, 8443/tcp, 0.0.0.0:9080->9080/tcp, 9000/tcp, 0.0.0.0:9443->9443/tcp'
    [ "$output" = "9080 9443" ]
}

@test "the v4/v6 pair collapses to one entry" {
    run ports '0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp'
    [ "$output" = "3001→3000" ]
}

@test "an identical host and container port shows once" {
    run ports '0.0.0.0:5432->5432/tcp'
    [ "$output" = "5432" ]
}

@test "a localhost binding is marked" {
    run ports '127.0.0.1:8080->80/tcp'
    [ "$output" = "lo:8080→80" ]
}

@test "a non-tcp protocol is kept" {
    run ports '0.0.0.0:53->53/udp'
    [ "$output" = "53/udp" ]
}

@test "exposed-only ports yield nothing by default" {
    run ports '5432/tcp, 8080/tcp'
    [ "$output" = "" ]
}

@test "exposed-only ports are marked with ~ when asked for" {
    run ports '5432/tcp, 8080/tcp' true
    [ "$output" = "~5432 ~8080" ]
}

# Deduping on the rendered label rather than skipping [::] means a port
# published on IPv6 ONLY still appears.
@test "an IPv6-only publish still appears" {
    run ports '[::]:3001->3000/tcp'
    [ "$output" = "3001→3000" ]
}

@test "empty in, empty out" {
    run ports ''
    [ "$output" = "" ]
}

# --- duration and status compaction -----------------------------------------

dur() { lib_call "$F/basic" "_short_duration '$1'"; }
st()  { lib_call "$F/basic" "_short_status '$1'"; }

@test "hours shorten" {
    run dur '5 hours ago'
    [ "$output" = "5h" ]
}

@test "weeks shorten" {
    run dur '3 weeks ago'
    [ "$output" = "3w" ]
}

# minutes and months both start with m and must not collide
@test "minutes become m" {
    run dur '20 minutes ago'
    [ "$output" = "20m" ]
}

@test "months become mo" {
    run dur '2 months ago'
    [ "$output" = "2mo" ]
}

@test "docker's 'About an hour' is understood" {
    run dur 'About an hour ago'
    [ "$output" = "1h" ]
}

@test "docker's 'About a minute' is understood" {
    run dur 'About a minute ago'
    [ "$output" = "1m" ]
}

@test "a healthy container is marked" {
    run st 'Up 5 hours (healthy)'
    [ "$output" = "Up 5h +" ]
}

@test "an unhealthy container reads differently" {
    run st 'Up 2 minutes (unhealthy)'
    [ "$output" = "Up 2m !" ]
}

@test "a starting container reads differently again" {
    run st 'Up 3 seconds (starting)'
    [ "$output" = "Up 3s ~" ]
}

# 137 is an OOM kill and 0 is a clean stop. Collapsing both to "Exited" throws
# away the only part that says which happened.
@test "an exit code survives compaction" {
    run st 'Exited (137) 3 minutes ago'
    [ "$output" = "Exit 137 · 3m" ]
}

@test "a clean exit survives too" {
    run st 'Exited (0) 2 days ago'
    [ "$output" = "Exit 0 · 2d" ]
}

# --- dps --------------------------------------------------------------------

@test "dps names its scope" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"docker ps"* ]]
}

@test "dps counts the rows" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"4 of 4"* ]]
}

@test "dps follows docker ps column order" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"CONTAINER ID  IMAGE  "* ]]
}

@test "dps ends with NAMES, as docker does" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"NAMES"* ]]
}

@test "dps shows the id in full" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"a1b2c3d4e5f6"* ]]
}

@test "dps shows the image" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"nginx:alpine"* ]]
}

# A cut tag cannot tell you which build is running.
@test "dps does not truncate a long image" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"quay.io/example/very-long-image-name:1.2.3"* ]]
}

@test "dps ellipsizes nothing in a row" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" != *"…"* ]]
}

@test "dps compacts the ports" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"9080"* ]]
}

@test "dps shows no raw docker port syntax" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" != *"0.0.0.0:"* ]]
}

@test "dps shows no /tcp noise" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" != *"/tcp"* ]]
}

@test "dps shows a dash when a container publishes nothing" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"—"* ]]
}

@test "dps -x reveals the exposed ports" {
    run in_dir "$F/basic" 'dps -x'
    [[ "$output" == *"~5432"* ]]
}

@test "dps carries an OOM exit code to the table" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"137"* ]]
}

@test "dps shows CREATED relative by default" {
    run in_dir "$F/basic" 'dps'
    [[ "$output" == *"3w"* ]]
}

@test "dps -t switches CREATED to a date" {
    run in_dir "$F/basic" 'dps -t'
    [[ "$output" == *"2026-06-30"* ]]
}

# docker prints the zone offset twice
@test "dps -t drops the doubled zone offset" {
    run in_dir "$F/basic" 'dps -t'
    [[ "$output" != *"-0400 -04"* ]]
}

@test "dps filters on a pattern" {
    run in_dir "$F/basic" 'dps fx'
    [[ "$output" == *"2 of 4"* ]]
}

@test "dps says what it filtered on" {
    run in_dir "$F/basic" 'dps fx'
    [[ "$output" == *"filter:"* ]]
}

@test "dps excludes what the pattern missed" {
    run in_dir "$F/basic" 'dps fx'
    [[ "$output" != *"other-api"* ]]
}

# --- dcps -------------------------------------------------------------------

@test "dcps names its scope" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"compose ps"* ]]
}

@test "dcps ends with SERVICE" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"SERVICE"* ]]
}

@test "dcps shows the container id" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"a1b2c3d4e5f6"* ]]
}

@test "dcps shows the image" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"postgres:18-alpine"* ]]
}

@test "dcps keeps the localhost mark" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"lo:8080→80"* ]]
}

@test "dcps keeps udp" {
    run in_dir "$F/basic" 'dcps'
    [[ "$output" == *"53/udp"* ]]
}

@test "dcps filters on a pattern" {
    run in_dir "$F/basic" 'dcps db'
    [[ "$output" == *"1 of 3"* ]]
}

# --- errors -----------------------------------------------------------------

@test "dps exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dps -Z'
    [ "$output" = "1" ]
}

@test "dcps exits 1 on an unknown flag" {
    run rc_of "$F/basic" 'dcps -Z'
    [ "$output" = "1" ]
}

@test "dps renders a table even when nothing matches" {
    run in_dir "$F/basic" 'dps zzzz'
    [[ "$output" == *"0 of 4"* ]]
}

@test "dps says plainly when there is nothing to show" {
    run in_dir "$F/basic" 'dps zzzz'
    [[ "$output" == *"nothing to show"* ]]
}
