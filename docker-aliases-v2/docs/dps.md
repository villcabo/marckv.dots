# `dps` / `dcps` — list containers and services

Two commands, no variants. `dps` covers the whole host; `dcps` covers the
project you are standing in.

- **Source:** [`commands/dps.sh`](../commands/dps.sh) · [`commands/dcps.sh`](../commands/dcps.sh)
- **Docs for both live here** — they are the same command at two scopes.

---

## Why the variants are gone

v1 had six ways to list things:

| v1 | What it was for |
|---|---|
| `dps` | everything, ports included |
| `dps1` | **the same, minus ports** |
| `dpsp` | **ports and almost nothing else** |
| `dcps` | compose, everything |
| `dcps -c` | **the same, minus ports** |
| `dcps -p` | **ports and almost nothing else** |

Four of those six exist for one reason: the PORTS column was so wide it pushed
the row off the screen, so you needed a view without it — and then another view
to see the ports you had just removed.

That is not six views anyone wanted. It is one view with a broken column.
Fix the column and the variants have no reason to exist.

## Usage

```
dps  [flags] [pattern...]      # every container on this host
dcps [flags] [pattern...]      # the services of this project
```

## Flags

| Flag | Meaning | `dps` | `dcps` |
|---|---|:--:|:--:|
| `-a` | Include stopped | ✓ | ✓ |
| `-x` | Show exposed-but-unpublished ports, marked `~` | ✓ | ✓ |
| `-f <file>` | Compose file | | ✓ |
| `-e <file>` | Env file | | ✓ |
| `-P <profile>` | Compose profile | | ✓ |
| `-h`, `--help` | Help | ✓ | ✓ |

`-x` rather than `-e` for "exposed", because `-e` is the env file in every other
command and a letter never gets a second meaning.

Patterns are regular expressions — container names for `dps`, service names for
`dcps` — the same rule as [`dclt`](dclt.md), [`dcdown`](dcdown.md) and
[`dcd`](dcd.md).

## What it looks like

```
   docker ps  ·  3 of 17  ·  filter: redmine
  NAME               PROJECT         STATUS                PORTS
  redmine            redmine-docker  Up 4 hours            3001→3000
  redmine-db-backup  redmine-docker  Up 4 hours (healthy)  —
  redmine-postgres   redmine-docker  Up 4 hours (healthy)  —
```

```
   compose ps  ·  3 of 3
  SERVICE   NAME               STATUS                PORTS
  redmine   redmine            Up 4 hours            3001→3000
  backup    redmine-db-backup  Up 4 hours (healthy)  —
  postgres  redmine-postgres   Up 4 hours (healthy)  —
```

`dps` shows the PROJECT because with many projects running that is the column
that tells you where a container came from — and it is what [`dcd`](dcd.md)
takes you to. `dcps` shows the SERVICE first, because inside a project that is
the name you actually type into `dclt`, `dcx` and `dcup`.

## The ports column

Everything above hinges on this. Real output from a real container:

```
8080/tcp, 8443/tcp, 0.0.0.0:9080->9080/tcp, 9000/tcp, 0.0.0.0:9443->9443/tcp
```

76 characters, of which 9 carry information. Three rules bring it down:

| Rule | Why | Result |
|---|---|---|
| Drop the address-family duplicate | `0.0.0.0:3001->3000/tcp` and `[::]:3001->3000/tcp` are one port printed twice | `3001→3000` |
| Drop exposed-but-unpublished | `9000/tcp` with no arrow cannot be reached from the host at all | *gone* |
| Collapse identical pairs | `9080->9080` says nothing `9080` does not | `9080` |

That line becomes `9080 9443`.

Two things are kept because they change the meaning:

- `127.0.0.1:5432->5432/tcp` → **`lo:5432`** — bound to localhost, not
  reachable from another machine.
- `0.0.0.0:53->53/udp` → **`53/udp`** — protocol is not tcp.

**Compaction, not truncation.** Nothing that could be reached is hidden; only
what was duplicated or unreachable is removed. `-x` brings the exposed ones
back, marked `~5432` so they never read as something you can connect to.

## Long names are shortened visibly

One 51-character container name would stretch the table past the screen — the
very problem the ports work was solving. Columns are capped and over-long
values are shortened **from the middle**, keeping both ends:

```
cross-border-st…border-support-1
```

The project prefix could have been stripped instead, since the PROJECT column
already carries it — it would read better. It was rejected on purpose: that
produces a name that looks real and is not, and pasting it into `docker exec`
fails. An ellipsis cannot be mistaken for a name.

## Colors

Rendered here rather than piped through `docker-color-output`. We choose the
format, so we are the only ones who know which column means what — and health
is pulled out of the status string rather than left buried in it:

| | |
|---|---|
| green | running, or `(healthy)` |
| yellow | restarting, paused, or `(starting)` |
| red | exited, or **`(unhealthy)`** |

An unhealthy container reads as red instead of looking exactly like a healthy
one with different words after it.

## Notes

**No preview block.** Every other v2 command renders one; here the table *is*
the output and a preview would state it twice. The scope line — command, how
many of how many, and the filter — carries the same information in one line.

## Related

- [`dcd`](dcd.md) — jump to the project a container belongs to
- [`dclt`](dclt.md) · [`dcx`](dcx.md) · [`dcup`](dcup.md) · [`dcdown`](dcdown.md)
