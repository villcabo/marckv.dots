# `dlt` — tail container logs, host-wide

- **Source:** [`commands/dlt.sh`](../commands/dlt.sh)
- **Tests:** [`tests/cases/dlt.bats`](../tests/cases/dlt.bats)
- **Completion:** [`completions/dlt.bash`](../completions/dlt.bash) · [`completions/dlt.zsh`](../completions/dlt.zsh)

`dclt`'s counterpart outside a compose project — the way `dps` is `dcps`'s and
`dver` is `dcver`'s. Same flags, same regex matching, no compose file anywhere.

## Usage

```
dlt [flags] [lines] [pattern...]
```

## Flags

| Flag | Meaning |
|---|---|
| `-n <N\|all>` | Lines to tail (default 100) |
| `-s <time>` | Only logs since then — `10m`, `1h`, a timestamp |
| `-o` | Once: dump and exit instead of following |
| `-t` | Prefix every line with its timestamp |
| `-a` | Match stopped containers too |
| `-h`, `--help` | Show the built-in help |

Short flags combine: `-ot` is `-o -t`. A bare number is the line count, so
`dlt 500 api` is `dlt -n 500 api` — which is what replaces any urge to add
`dlt100` and `dlt500` alongside it.

## One container, or several

This is the whole difficulty of the command, and the reason it is not a
three-line alias.

`docker compose logs` takes a list of services and interleaves them itself.
**`docker logs` takes exactly one container.** So matching several means running
one `docker logs` per container and interleaving them here.

A **single** match is handed straight to docker:

```
$ dlt -o -n 2 postgres
2026-08-24 19:04:11.001 UTC [1] LOG:  database system is ready
2026-08-24 19:04:11.118 UTC [1] LOG:  autovacuum launcher started
```

No prefix, no wrapper process, docker's own exit code. With one container a
prefix on every line is noise.

**Several** get the container name in front, coloured and padded into a column
— the only thing that makes interleaved output readable:

```
$ dlt -o -n 1 'marckv-'
marckv-debian11 | root@debian11:~#
marckv-debian12 | root@debian12:~#
marckv-debian13 | root@debian13:~#
```

### Nothing is left running

Following several containers means several background `docker logs --follow`,
and they have to go when you press Ctrl-C.

What gets recorded is the PID of `docker logs`, **not** the one `$!` reports for
the pipeline. Measured in both shells: killing the PID `$!` gives for
`{ a | b; } &` leaves **a and b both running**, so every Ctrl-C would strand a
`docker logs --follow` per container. Killing the producer instead closes the
prefixer's stdin, and it leaves on its own.

Verified end to end — three containers followed, interrupted, and counted:

```
base        : 0
following   : 3
interrupted : 0
```

in bash and in zsh.

## Patterns are always regular expressions

Matched against **container names**, host-wide, as in [`dps`](dps.md) and
[`dver`](dver.md) — not against compose service names, which is what
[`dclt`](dclt.md) matches.

```bash
dlt api             # anything containing 'api'
dlt 'api|db'        # either
dlt '^redmine$'     # exactly that container
```

With no pattern, every running container is followed. `-a` widens the match to
stopped ones, whose logs `docker logs` still serves.

## The preview

Mandatory, like everywhere else here, and **on stderr** — so a dump you pipe
stays clean:

```bash
dlt -o api | grep -i error      # the preview does not land in the pipe
```

There is no confirmation. Reading logs changes nothing, and making someone type
`yes` to look at a log is friction with no payoff.

## Errors

Nothing matched names the containers that exist, rather than leaving you to run
`dps` yourself:

```
$ dlt nosuch
  dlt: no container matched: nosuch
  available: fx-api fx-db other-api plain-box
```

With no containers running at all, it says so and points at `-a`.

## Related

- [`dclt`](dclt.md) — the same command inside a compose project, where compose
  supplies the service list and does the interleaving
- [`dps`](dps.md) — what is running, host-wide
- [README](../README.md)
