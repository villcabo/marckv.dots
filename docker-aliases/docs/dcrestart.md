# `dcrestart` — restart compose services, and say what a restart will not do

`docker compose restart` looks like the simplest command there is. It has three
behaviours nobody expects, and `dcrestart`'s preview names each one, for the
exact services it applies to, before you confirm.

- **Source:** [`commands/dcrestart.sh`](../commands/dcrestart.sh)
- **Completion:** [`completions/dcrestart.bash`](../completions/dcrestart.bash) · [`completions/dcrestart.zsh`](../completions/dcrestart.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcrestart [-f file] [-e file] [-P profile] [-t seconds] [service-pattern...]
```

## Flags

| Flag | Meaning |
|---|---|
| `-f file` | Compose file (repeatable). Default: resolved as docker does, override included |
| `-e file` | Env file (repeatable) |
| `-P profile` | Profile (repeatable, or comma-separated) |
| `-t seconds` | Grace period before SIGKILL (docker's default: 10) |
| `-h`, `--help` | Show the built-in help |

Patterns are regexes over the declared services, as in [`dcdown`](dcdown.md).
No pattern restarts the whole project.

## What a restart does not do

All three measured against `docker compose` on a throwaway project:

**1. It does not apply a changed compose file.** The container comes back with
the configuration it was created with. Change an environment variable, restart,
and the old value is still there; `up` is what applies it. `dcrestart` detects
this **exactly**, not by guessing: compose stamps every container with the hash
of the service config it was created from, and `config --hash` gives today's.
When they differ:

```
  [!] web changed in the compose file since it was created —
      a restart brings back the OLD config. To apply the change: dcup web
```

**2. It starts stopped services too.** "Restart" does not sound like "bring up
what was down":

```
  [!] worker is stopped — a restart starts it too
```

**3. It skips a service that was never created — silently, with exit code 0.**
`dcrestart` says so, and when none of the services you asked for has a
container it refuses instead of running a no-op:

```
  [!] extra has no container — a restart skips it in silence; dcup creates it

  dcrestart: no container exists for: extra
  restart only acts on containers that exist — create them with dcup
```

## Preview

```
  compose restart
  compose.yaml
  extra web worker
  -t 1
  docker compose -f compose.yaml restart -t 1
  ──────────────────────────────────────────────────────────────────
  [!] web changed in the compose file since it was created —
      a restart brings back the OLD config. To apply the change: dcup web
  [!] worker is stopped — a restart starts it too
  [!] extra has no container — a restart skips it in silence; dcup creates it
  Continue? [yes/N]
```

The confirmation takes the full word `yes`.

If docker cannot be asked what is running, the preview says the warnings are
**missing**, not that there is nothing to warn about.

## Examples

```bash
dcrestart                  # every service of the project
dcrestart api              # services matching 'api'
dcrestart -t 30 kafka      # give kafka 30 seconds to stop cleanly
dcrestart -P debug         # with a profile active
```

## Performance

The preview costs one `compose ps` and one `compose config --hash` on top of
service discovery — about 80 ms each, paid once, before a confirmation.

## Exit codes

| Code | When |
|---|---|
| 0 | The restart ran (compose's own exit code otherwise) |
| 1 | No compose file, nothing matched, no container for any requested service, the confirmation was declined, or an unknown flag |

## Related

- [`dcup`](dcup.md) — what applies a changed compose file
- [`drestart`](drestart.md) — restart any container on the host by name
- [`devents`](devents.md) — what happened to it
