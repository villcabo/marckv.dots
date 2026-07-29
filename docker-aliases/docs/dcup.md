# `dcup` — bring Docker Compose services up

Wraps `docker compose up -d` with a mandatory preview and confirmation, so a
recreate or restart never happens because of a mistyped flag.

- **Source:** [`commands/dcup.sh`](../commands/dcup.sh)
- **Completion:** [`completions/dcup.bash`](../completions/dcup.bash) · [`completions/dcup.zsh`](../completions/dcup.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcup [flags] [service...]
```

With no services named, every service in the compose file is started.

## Flags

| Flag | Maps to | Meaning |
|---|---|---|
| `-r` | `--force-recreate` | Recreate containers even if nothing changed |
| `-p` | `--pull always` | Pull images before starting |
| `-b` | `--build` | Build images before starting |
| `-l` | — | Follow logs after the services are up |
| `-f <file>` | `-f` | Compose file to use. Repeatable |
| `-e <file>` | `--env-file` | Env file to use. Repeatable |
| `-P <profile>` | `--profile` | Compose profile. Repeatable, or comma-separated |
| `-h`, `--help` | — | Show the built-in help |

Short flags combine: `-rpl` is exactly `-r -p -l`. A flag that takes a value
(`-f`, `-e`, `-P`) simply has to be last in its cluster — `-rf prod.yml` works
and means `-r -f prod.yml`.

`-P` accepts either form:

```bash
dcup -P dev -P debug      # repeated
dcup -P dev,debug         # comma-separated
```

### Profiles change which services exist

`COMPOSE_PROFILES` in your environment or `.env` is applied by docker on its
own, and every command here reflects it — the preview, the table and TAB
completion all list the services that profile actually brings in.

**`-P` replaces `COMPOSE_PROFILES`, it does not add to it.** That is docker's
behaviour, not ours: with `COMPOSE_PROFILES=dev` in `.env`, `dcup -P debug`
enables `debug` alone. These commands follow the same rule, so what the preview
names is what the command starts.

## Examples

```bash
dcup                              # start every service
dcup api worker                   # start only these services
dcup -r                           # force recreate everything
dcup -rl                          # recreate, then follow logs
dcup -rpl api                     # recreate + pull + logs, for 'api'
dcup -f prod.yml -r               # custom compose file
dcup -f base.yml -f override.yml  # layer multiple compose files
dcup -e .env.prod                 # custom env file
dcup -P dev,debug                 # enable two profiles
```

## Compose file resolution

When `-f` is not given, the file is resolved in this order:

1. `$COMPOSE_FILE` — docker's own variable, holding a **list**
2. `COMPOSE_FILE=` inside `./.env` — same, docker reads it there too
3. `$DOCKER_COMPOSE_FILE` — a v1 invention, one file, kept working
4. `DOCKER_COMPOSE_FILE=` inside `./.env`
5. `./docker-compose.yml` / `.yaml` (or `compose.yml` / `.yaml`), **plus its
   `.override.` sibling when one exists**

If none of these exist, `dcup` stops with an error and runs nothing.

`COMPOSE_FILE` is a separated list, not one path — `:` by default, or whatever
`COMPOSE_PATH_SEPARATOR` says:

```
COMPOSE_FILE=docker-compose.yml:docker-compose.http.yml:docker-compose.obs.yml
```

Every one of those is used. Setting it also **disables** docker's automatic
`docker-compose.override.yml` merge, and these commands follow suit — your list
is the whole truth.

This resolution is shared by every command here, so `dcup`, `dclt`, `dcps` and
TAB completion all act on exactly the files `docker compose` would.

## The preview

Every run renders a preview and waits. There is no way to turn it off.

```
   compose up
   docker-compose.yml
   api
   --force-recreate --pull always
   docker compose -f docker-compose.yml up -d --force-recreate --pull always api
──────────────────────────────────────────────────────────────────────────
   Continue? [yes/N]
```

Line by line:

| Line | Shows |
|---|---|
|  action | The operation, colored green because `up` creates |
|  file | Every compose file in play, one per line |
|  services | The services that will be touched — the resolved list, not a guess |
|  flags | The docker flags your short flags expanded into |
|  command | **The exact command that will run** |

The command line is not a reconstruction. `dcup` builds one command, renders
those same pieces, and executes it — with no `eval` anywhere. Quoting cannot
drift between what you read and what runs, including paths with spaces.

Without a Nerd Font (`DOCKER_ALIASES_NERD_FONT=0`) the same block renders with
ASCII markers:

```
  [docker] compose up
  [file] docker-compose.yml
  [svc] api
  [flags] --force-recreate --pull always
  $ docker compose -f docker-compose.yml up -d --force-recreate --pull always api
──────────────────────────────────────────────────────────────────────────
  [?] Continue? [yes/N]
```

## Confirmation

You must type the full word **`yes`**. `YES` and `Yes` also work.

Anything else cancels — including a bare `y`, and including plain Enter. The
full word is deliberate: `dcup` recreates and restarts running services, and a
single keystroke is too easy to hit by accident.

**There is no `-y` flag.** For tests and CI only, `DOCKER_ALIASES_AUTO_YES=1`
bypasses the prompt. An env var is far harder to trigger by accident than a
mistyped flag, which is exactly why the escape hatch takes that shape.

## Exit codes

| Code | When |
|---|---|
| `0` | Services started (and logs exited cleanly, with `-l`) |
| `1` | Cancelled at the prompt, or a bad flag / missing file |
| other | Passed straight through from `docker compose` |

## Notes

**`--env-file` position.** `--env-file` is an option of `docker compose`
itself, not of the `up` subcommand, so `dcup` emits it *before* `up`:

```
docker compose -f docker-compose.yml --env-file .env.prod up -d
```

The v1 implementation placed it after `up -d`, where `docker compose` rejects
it. If you relied on `-e` in v1, it never actually worked.

**Service list caching.** The service list shown in the preview comes from
`docker compose config --services`, cached for `DOCKER_ALIASES_CACHE_TTL`
seconds (default 5) per directory + compose-file combination. Set it to `0` to
disable. The cache only feeds the display and TAB completion — never the
command that runs.

## Related

- [README](../README.md) — layout and design rules
