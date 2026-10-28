# `devents` — what happened to a container, and why

The question after an incident is never "list the events". It is **"what
happened to this container?"** — why it is down, whether the kernel killed it,
whether docker tried to bring it back, what it said before it died. `devents`
answers that, in plain words.

- **Source:** [`commands/devents.sh`](../commands/devents.sh)
- **Completion:** [`completions/devents.bash`](../completions/devents.bash) · [`completions/devents.zsh`](../completions/devents.zsh)
- **Shells:** bash and zsh

---

## Usage

```
devents [-a] [-f] [pattern]
```

The pattern is a regex over **every** container, stopped ones included — a
post-mortem is about the dead. A pattern that *is* a container's name picks it
even when it also matches others, so `devents keycloak` does not drown in
`keycloak-db`.

| Match | You get |
|---|---|
| none given, or several | a table of what happened |
| exactly one | that container's story |

## Flags

| Flag | Meaning |
|---|---|
| `-a` | Table: all time, not only the last 24 hours |
| `-f` | Follow events live, for one container or the whole host (Ctrl-C to stop) |
| `-h`, `--help` | Show the built-in help |

## Why it does not just use `docker events`

Because `docker events --since 24h` lies. The daemon keeps **the last 256
events for the whole host**, in memory, and every healthcheck probe adds three
of them. Measured on a host with fifteen healthchecks: "the last 24 hours"
reached back **33 seconds**. A timeline built on events is empty exactly when
you need it — and an empty timeline reads as "nothing happened".

What survives is on the container itself: its exit code, whether the OOM
killer took it, how many times its restart policy brought it back, when it
started and ended, and its logs. That is the backbone of everything `devents`
shows. The events are shown too, with an honest note of how far back they
reach.

## The story of one container

```
  story  ·  nginx-api-ws-log-trim-1  ·  exited (137)
  why       killed (SIGKILL) — kill, or stop timeout
            its policy is unless-stopped, so docker would have restarted a crash —
            it was stopped on purpose (docker stop, compose stop/down).
            not the OOM killer — docker records that separately.
  restart   policy unless-stopped  ·  restarted 0 times
  lived     started 22:47:41  ·  ended 22:47:59 (23m ago)  ·  up 18s
  created   22:47:39  from alpine:3.24.2
  ──────────────────────────────────────────────────────────────────
  recent events — docker keeps the last 256 for the whole host; here that reaches back 34s
  none in that window — the story above is what the container remembers
  ──────────────────────────────────────────────────────────────────
  last log lines
  22:47:41  log-trim: /var/log/gateway/access.json reached 2002087 bytes; …
  more with docker logs --tail 100 nginx-api-ws-log-trim-1
```

**`why` is the line it exists for.** The exit code is interpreted, and what
the restart policy implies is said out loud:

| What docker recorded | What `devents` tells you |
|---|---|
| `OOMKilled=true` | out of memory — the OOM killer |
| `137`, not OOM | SIGKILL: `docker kill`, or `docker stop` after its grace period ran out |
| `143` | stopped with SIGTERM — a normal `docker stop` |
| `0` | exited cleanly |
| `127` / `126` | the command was not found / not executable |
| `125` | docker itself could not start it |
| `139` / `134` | segfault / abort |
| `128+n` | killed by signal *n* |
| anything else | an application error |
| `always`/`unless-stopped` + exited | it was stopped on purpose: docker would have restarted a crash |
| `on-failure:N`, restarted N times | docker gave up |

**Last log lines** appear when the container is down or has been restarted —
the last words are usually the answer. A container running fine shows none.

**Health** appears only while the container runs. A stopped container keeps
the last health it had, and `unhealthy` on a dead container describes a probe
nobody runs any more.

### Watching it happen

The events that *are* in the buffer tell their own story. `docker restart -t 1`
on a process that ignores SIGTERM:

```
  23:12:14  kill     SIGTERM
  23:12:15  kill     SIGKILL
  23:12:15  stop
  23:12:15  die      exit 137 — killed (SIGKILL) — kill, or stop timeout
  23:12:15  start
  23:12:15  restart
```

The SIGKILL a second after the SIGTERM is the grace period running out — the
classic 137 of a `sleep` running as PID 1.

## The table

```
  what happened  ·  38 of 190  ·  filter: last 24h
  WHEN  STATE    EXIT  RESTARTS  WHY                                           NAME
  3m    exited   3     3         application error — gave up after 3 restarts  payments-worker
  3m    exited   137   0         out of memory — the OOM killer                report-builder
  18m   running  —     0         unhealthy — see dhealth                       gateway
  1h    running  —     0         started                                       keycloak
  152 untouched in 24h, see devents -a · one container's story: devents <name>
```

Newest first. Without a pattern it covers what ended, restarted or started in
the last 24 hours, plus anything restarting, dead or unhealthy however old it
is. With a pattern, every match shows: the pattern already did the narrowing.

## Following live

```bash
devents -f api      # one container: its events as they happen
devents -f          # the whole host, each line naming its container
```

Healthcheck probes (`exec_*`) and terminal noise (`resize`, `attach`) are
hidden — on a busy host they are most of the stream and none of the story.

## Examples

```bash
devents                  # what happened on this host today
devents -a               # the whole history docker remembers
devents payments         # why payments is in the state it is
devents -f payments      # watch it crash-loop
```

## Exit codes

| Code | When |
|---|---|
| 0 | The table was shown, or the one container is up |
| 1 | The one container is exited, dead or restarting; nothing matched; `-f` matched several; an unknown flag; no daemon |

## Performance

| Mode | Calls | Measured |
|---|---|---|
| table | `ps -a`, one `inspect` of every container, one `date` | ~510 ms with 190 containers (bare `ps -a` + `inspect`: ~400 ms) |
| story | `inspect`, one `events`, `logs` when down, one `date` | ~380 ms |

Every timestamp on screen goes through **one** GNU `date -f -` call, which
reads a list: no fork per row, and the local clock stays right across a
daylight-saving change.

Two measured traps the story avoids: `docker events --until` with a time in the
future turns the query into a live stream and **waits** for that time (~950 ms
of pure waiting); a whole second as `--until` cuts off the events of the current
second. So `--until` is the current instant with nanoseconds.

## Notes

- **No preview, no confirmation.** It only reads.
- The footer goes to stderr, so `devents | grep x` gets only the table.

## Related

- [`dhealth`](dhealth.md) — what a healthcheck runs and what its probes printed
- [`dlt`](dlt.md) — the logs, in full
- [`dps`](dps.md) — every container, right now
