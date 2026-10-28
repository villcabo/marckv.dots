# `drestart` — restart running containers by name, host-wide

[`dcrestart`](dcrestart.md) restarts services of the compose project you are
standing in. `drestart` restarts any running container on the host, wherever it
came from, after showing you exactly which ones.

- **Source:** [`commands/drestart.sh`](../commands/drestart.sh)
- **Completion:** [`completions/drestart.bash`](../completions/drestart.bash) · [`completions/drestart.zsh`](../completions/drestart.zsh)
- **Shells:** bash and zsh

---

## Usage

```
drestart [-t seconds] pattern
```

## Flags

| Flag | Meaning |
|---|---|
| `-t seconds` | Grace period before docker sends SIGKILL (docker's default: 10). `-t5` works too |
| `-h`, `--help` | Show the built-in help |

## Matching

The pattern is a regex over **running** containers, and it is **required** —
there is no restart-everything default. `drestart .` is there for whoever
means it, and the preview will count it out loud.

- **Several matches restart them all**, and the preview names each one first.
- **A pattern that is a container's name means that container alone.**
  `drestart keycloak` leaves `keycloak-db` and `keycloak-local` running; to
  restart all three, say `drestart '^keycloak'`.
- **A stopped container is never restarted.** Restarting something that is not
  running is a start in disguise. If the pattern only matches stopped
  containers, `drestart` names them and gives you the command that starts them:

```
  drestart: no running container matched: payments
  it matches stopped container(s) — drestart only restarts running ones:
    payments-worker  start it with docker start payments-worker
```

## Preview

```
  restart  ·  2 container(s)
  srv-debian  bastion-lab/srv-debian
  srv-ubuntu  bastion-lab/srv-ubuntu
  docker restart srv-debian srv-ubuntu
  ──────────────────────────────────────────────────────────────────
  [!] 2 from compose: a restart keeps the config they were created with — dcup applies a changed compose file
  Restart 2 container(s)? [yes/N]
```

Each container comes with its compose project and service: a bare name does
not tell you which project it belongs to. Containers that compose created get
one line of warning — a restart brings back the configuration a container was
**created** with, so an edited compose file is not applied (measured: change an
environment variable, restart, and the old value is still there).

The confirmation takes the full word `yes`. A restart interrupts whatever the
container is serving.

## The grace period, and exit code 137

`docker restart` sends SIGTERM, waits `-t` seconds, then sends SIGKILL. A
process that ignores SIGTERM — a shell script, a `sleep` running as PID 1 —
always gets killed, and exits with 137. [`devents`](devents.md) shows it
happening:

```
  23:21:40  kill     SIGTERM
  23:21:41  kill     SIGKILL
  23:21:41  die      exit 137 — killed (SIGKILL) — kill, or stop timeout
```

If that 137 is a surprise, the process is not handling SIGTERM; a longer `-t`
only makes the wait longer.

## Examples

```bash
drestart keycloak          # just keycloak
drestart '^srv-'           # every container whose name starts with srv-
drestart -t 30 kafka       # give kafka 30 seconds to stop cleanly
```

## Exit codes

| Code | When |
|---|---|
| 0 | The restart ran (docker's own exit code otherwise) |
| 1 | No pattern, nothing running matched, the confirmation was declined, an unknown flag, or no daemon |

## Notes

- The preview goes to stderr.
- No `-y`: `DOCKER_ALIASES_AUTO_YES=1` exists for tests and CI only.

## Related

- [`dcrestart`](dcrestart.md) — restart services of the current compose project
- [`devents`](devents.md) — what happened to it, before and after
- [`dps`](dps.md) — what is running
