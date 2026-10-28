# `dhealth` — why a container is (un)healthy

`dps` already tells you a container is unhealthy. `dhealth` tells you **why**:
what the healthcheck runs, how often, and what the last probes printed. That
information is in `docker inspect`, as nested JSON — and with no `jq` on the
server, reading it by hand is the slowest part of a bad night.

- **Source:** [`commands/dhealth.sh`](../commands/dhealth.sh)
- **Completion:** [`completions/dhealth.bash`](../completions/dhealth.bash) · [`completions/dhealth.zsh`](../completions/dhealth.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dhealth [pattern]
```

The pattern is a regex over running container names. **How many it matches
decides the mode:**

| Match | You get |
|---|---|
| none given, or several | a table of every container that has a healthcheck |
| exactly one | the full diagnosis of that container |

## Flags

| Flag | Meaning |
|---|---|
| `-h`, `--help` | Show the built-in help |

## The table

```
  [docker] docker health  ·  15 of 15
  STATUS     FAILS  LAST      EXIT  EVERY  NAME
  unhealthy  160    22:58:45  7     2s     payments-worker
  healthy    —      22:58:44  0     5s     keycloak
  healthy    —      22:58:35  0     30s    kafka
  18 running container(s) have no healthcheck — "Up" is all docker knows about them
  [!] 1 unhealthy — see why with dhealth <name>
```

**Sick first.** Rows are ordered `unhealthy`, then `starting`, then `healthy`:
on a host with forty healthchecks, the failing one must not be row 23.

| Column | Means |
|---|---|
| `FAILS` | consecutive failed probes — `—` when the streak is zero |
| `LAST` | when the last probe finished |
| `EXIT` | what it exited with — `0` is a pass |
| `EVERY` | the probe interval |

**Containers with no healthcheck are counted, not listed.** "Up" in `dps` only
means the process is running, not that it answers — the count says how much of
the host docker knows nothing about.

## The diagnosis

```
  health  ·  payments-worker  ·  unhealthy  (160 failed in a row)
  test      CMD-SHELL curl -fsS http://localhost:8080/health || exit 1
  every     2s  ·  timeout 2s  ·  retries 2  ·  start period default
  ──────────────────────────────────────────────────────────────────
  last probes, newest first
  22:58:45  exit 7  curl: (7) Failed to connect to localhost port 8080
  22:58:43  exit 7  curl: (7) Failed to connect to localhost port 8080
```

- **The probe command comes first.** When a check fails, the first question is
  "what is it actually checking?" — and the container name does not answer it.
- **Newest first.** docker stores the last five probes oldest first; the newest
  is the one you came for.
- **The first non-empty line** of each probe's output. A probe can print a whole
  HTTP response; the first line is the one that says why.
- **`default`** for an option the healthcheck never set — docker reports it as
  `0s`, which reads like a timeout of zero seconds.

A container with no healthcheck says so, instead of printing nothing:

```
  dxprobe-alpine has no healthcheck
  "Up" in dps only means the process runs — not that it answers.
```

## Examples

```bash
dhealth                    # every healthcheck on the host
dhealth keycloak           # why keycloak is in the state it is
dhealth api                # several match: the table, filtered
dhealth || notify "sick"   # as a check: exits 1 when anything is unhealthy
```

## Exit codes

| Code | When |
|---|---|
| 0 | Everything shown is `healthy` or `starting` |
| 1 | Something shown is `unhealthy`, the one match has no healthcheck, nothing matched, an unknown flag, or no daemon |

## Performance

One `docker ps` and one `docker inspect` for every match, whatever the number
of containers. Measured with 33 running containers: ~140 ms for the table,
~120 ms for one diagnosis, against ~120 ms for the bare `ps` + `inspect`.

## How it is built — and the trap it avoids

`docker inspect` runs the template against the typed container first and, if
that fails, **silently re-runs it against the raw JSON as a map**. In map mode
the types change (`5s` becomes `5000000000`, times change format) and a key
that is absent is fatal. Indexing a struct field — `index .State "Health"` —
is enough to fail the typed pass, and on a container with no healthcheck the
map pass then dies with `map has no entry for key "Healthcheck"`. So every
field here is reached by its typed path; an option nobody set is a zero value,
never a missing key.

Probe output can span several lines, so probes are split on the record
separator (`\x1e`), never on newlines.

## Notes

- **No preview, no confirmation.** It only reads.
- The footer goes to stderr, so `dhealth | grep x` gets only the table.

## Related

- [`dps`](dps.md) — every container, with the health glyph in `STATUS`
- [`devents`](devents.md) — when the health changed, in a container's timeline
