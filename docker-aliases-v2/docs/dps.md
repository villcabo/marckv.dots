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
| `-t` | Exact creation date instead of how long ago | ✓ | ✓ |
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
  CONTAINER ID  IMAGE                                        CREATED  STATUS  PORTS      NAMES
  7af3f67656e7  redmine-custom:6.1.2                         3w       Up 5h   3001→3000  redmine
  74a0260254eb  prodrigestivill/postgres-backup-local:latest 3w       Up 5h   —          redmine-db-backup
  50debfb8b76b  postgres:18-alpine                           3w       Up 5h   —          redmine-postgres
```

```
   compose ps  ·  3 of 3
  CONTAINER ID  IMAGE                                        CREATED  STATUS  PORTS      SERVICE
  7af3f67656e7  redmine-custom:6.1.2                         3w       Up 5h   3001→3000  redmine
  74a0260254eb  prodrigestivill/postgres-backup-local:latest 3w       Up 5h   —          backup
  50debfb8b76b  postgres:18-alpine                           3w       Up 5h   —          postgres
```

## The column order is `docker ps`'s

`CONTAINER ID · IMAGE · CREATED · STATUS · PORTS · NAMES` — the same sequence
docker uses, minus COMMAND. Muscle memory is worth more than any ordering we
could invent, and the identifier belongs last because that is where you have
learned to look for it.

`dcps` uses the same order with SERVICE in the last slot: inside a project that
is the name you type into `dclt`, `dcx` and `dcup`. Its container NAME column is
dropped — the ID already identifies the container exactly.

There is no PROJECT column. Seven columns do not fit in one row, and the project
is one command away: [`dcd`](dcd.md) takes you to it.

## Nothing is truncated

The image is shown **whole**. A tag is what tells you which build is running,
and `…support:v1.0.0` does not — so `cr.sintesis.com.bo/crossborder-dev/crossborder-support:v1.0.0`
appears in full, all sixty-one characters of it.

Names are whole too, and that one is free: the identifier is the **last**
column, and a last column needs no padding, so it can run as long as it likes
without pushing anything out of alignment.

The cost is honest — one long image widens that column for every row, exactly
as it does in `docker ps`. This table still comes out far narrower than
`docker ps` does, because the ports and the status are compacted and COMMAND is
gone entirely.

## STATUS and CREATED are not the same thing

This is the pair worth reading together:

| | Answers |
|---|---|
| `STATUS` — `Up 5h` | how long it has been **running** |
| `CREATED` — `3w` | when the container was **made** |

A container created `3w` ago showing `Up 5h` **restarted five hours ago**. That
gap is usually the thing you were trying to find out, and `docker ps` buries it
by putting them at opposite ends of a very wide row.

Both are compacted the same way: `5h`, `3w`, `20m`, `2mo`. `-t` swaps CREATED
for the exact date — `2026-06-30 22:04`, without the timezone offset docker
prints twice.

## Status is compacted, exit codes are not

| docker | here |
|---|---|
| `Up 5 hours (healthy)` | `Up 5h ` |
| `Up 2 minutes (unhealthy)` | `Up 2m ` *(in red)* |
| `Exited (137) 3 minutes ago` | `Exit 137 · 3m` |

Health becomes a heartbeat glyph — the **same** glyph in all three states, with
the colour saying which: green healthy, red unhealthy, yellow starting.

Without a Nerd Font the three states get distinct characters instead
(`+` `!` `~`). That asymmetry is deliberate: ASCII mode is the degraded path,
and whoever lost the font may have lost the colour too. **The exit code is kept**: `Exited (137)` is an
out-of-memory kill and `Exited (0)` is a clean stop, and collapsing both to
"Exited" throws away the only part that says which one happened.

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
