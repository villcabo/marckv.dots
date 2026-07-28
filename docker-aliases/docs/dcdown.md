# `dcdown` — stop and remove Docker Compose services

Brings the project down, with a confirmation that scales to what is actually
being destroyed.

- **Source:** [`commands/dcdown.sh`](../commands/dcdown.sh)
- **Completion:** [`completions/dcdown.bash`](../completions/dcdown.bash) · [`completions/dcdown.zsh`](../completions/dcdown.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcdown [flags] [pattern...]
```

With no pattern the whole project comes down.

## Flags

| Flag | Maps to | Meaning |
|---|---|---|
| `-v` | `--volumes` | **Delete named volumes — destroys data** |
| `-O` | `--remove-orphans` | Remove containers for services no longer declared |
| `-f <file>` | `-f` | Compose file to use. Repeatable |
| `-e <file>` | `--env-file` | Env file to use. Repeatable |
| `-P <profile>` | `--profile` | Compose profile. Repeatable, or comma-separated |
| `-h`, `--help` | — | Show the built-in help |

Short flags combine: `-vO` is `-v -O`. `-O` is capitalised because `-o` already
means *once* in [`dclt`](dclt.md), and a letter should not mean two things.

## Patterns are regular expressions

Same rules as [`dclt`](dclt.md):

```bash
dcdown api            # anything matching "api"
dcdown 'api|worker'   # two patterns at once
dcdown '^api$'        # exactly the service named "api"
```

Patterns match against the **declared** services, not the running ones — naming
a service that is already stopped is a perfectly reasonable thing to ask for.

## Two commands wearing one name

This is the idea the whole command is built around.

| | What it destroys | Getting it back |
|---|---|---|
| `dcdown` | Containers, networks | `dcup` |
| `dcdown -v` | Containers, networks, **named volumes** | **Nothing. The data is gone.** |

They are not the same operation, so they do not get the same confirmation.

### Without `-v`

```
   compose down
   docker-compose.yml
   cache db
   docker compose -f docker-compose.yml down
──────────────────────────────────────────────────────────────────────────
   nothing is running — this only removes networks
   Continue? [yes/N]
```

You type `yes`. The cost of a mistake is a restart.

### With `-v`

```
   compose down
   docker-compose.yml
   cache db
   pgdata redis_data  ← deleted, cannot be undone
   --volumes
   docker compose -f docker-compose.yml down --volumes
──────────────────────────────────────────────────────────────────────────
   This deletes 2 volume(s) permanently. Type the project name to confirm:
   [dav2-fixture-volumes]:
```

Two things change.

**The volumes are named.** Not "this will delete volumes" — the actual list,
read from `docker compose config --volumes`. If `pgdata` is on that line and you
did not expect it, you stop.

**The answer is the project name, not `yes`.** Not because `yes` is too short,
but because `yes` is the answer to *every other prompt*. Type it often enough
and you stop reading the question — the prompt becomes a keystroke. Asking for
the project name breaks that reflex: you cannot answer without looking at what
you are about to destroy.

`yes` is rejected here. So is the wrong project name.

## Running versus declared

`dcdown` asks the daemon which services are actually running, and always says
which picture you are looking at:

| Situation | What you see |
|---|---|
| Services running | Those services listed |
| Daemon reachable, nothing up | `nothing is running — this only removes networks` |
| Daemon unreachable | `could not reach the docker daemon — showing declared services` |

Those last two are deliberately different messages. "I asked and nothing is
running" and "I could not ask" mean very different things immediately before a
destructive command, and collapsing them into one message would be a lie of
omission.

## Errors

```
  dcdown: no service matched: zzz
  available: cache db
```

| Code | When |
|---|---|
| `0` | Services stopped and removed |
| `1` | Cancelled, no service matched, bad flag, missing file |
| other | Passed straight through from `docker compose` |

## Notes

**`DOCKER_ALIASES_AUTO_YES` bypasses the typed prompt too.** It exists for tests
and CI only, and there is still no CLI flag that reaches it — including for
`-v`.

**The project name comes from `docker compose config`,** not from the directory
name or a guess. Compose resolves it from `name:`, then `COMPOSE_PROJECT_NAME`,
then the directory, and only `config` knows which one won. It is parsed in pure
shell because a minimal server has no `jq`.

## Related

- [`dcup`](dcup.md) — bring services up
- [`dclt`](dclt.md) — tail logs
- [README](../README.md) — layout and design rules
