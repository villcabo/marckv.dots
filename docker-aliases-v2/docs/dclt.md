# `dclt` — tail Docker Compose logs

Follows logs for the services whose names match your patterns, so you never
have to type out the full list.

- **Source:** [`commands/dclt.sh`](../commands/dclt.sh)
- **Completion:** [`completions/dclt.bash`](../completions/dclt.bash) · [`completions/dclt.zsh`](../completions/dclt.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dclt [flags] [lines] [pattern...]
```

With no pattern, every service is followed.

## Flags

| Flag | Maps to | Meaning |
|---|---|---|
| `-n <N\|all>` | `--tail` | Lines to tail. Default `100`, or `$DOCKER_ALIASES_LOG_LINES` |
| `-s <time>` | `--since` | Only logs since then — `10m`, `1h`, or a timestamp |
| `-o` | *(drops `--follow`)* | Once: dump and exit instead of following |
| `-t` | `--timestamps` | Prefix every line with its timestamp |
| `-f <file>` | `-f` | Compose file to use. Repeatable |
| `-e <file>` | `--env-file` | Env file to use. Repeatable |
| `-P <profile>` | `--profile` | Compose profile. Repeatable, or comma-separated |
| `-h`, `--help` | — | Show the built-in help |

Short flags combine: `-ot` is `-o -t`. As in `dcup`, `-f` means **compose
file**, not "follow" — one convention across every command.

## Patterns are always regular expressions

```bash
dclt api          # api, api-worker, myapi — anything containing "api"
dclt 'api|db'     # two patterns at once
dclt '^api$'      # exactly the service named "api"
dclt api db       # several patterns, space separated
```

There is no `-r` flag, because there is nothing to switch on. In v1 a pattern
matched **exactly** unless you remembered `-r`, so `dclt api` silently matched
nothing when the service was called `api-worker`. Now the useful behavior is
the default and full regex is always available.

A service matched by two patterns is still listed once, and the matched set
comes out in the compose file's sorted order.

## Line count

A bare number is the line count — this is what replaces the idea of separate
`dclt100` / `dclt500` commands:

```bash
dclt 500 api      # same as dclt -n 500 api
dclt -n all api   # the entire log
```

Only pure digits are treated as a count, so a service name can never be
mistaken for one. `all` therefore needs `-n`.

## Examples

```bash
dclt                          # follow everything
dclt api                      # follow anything matching "api"
dclt 500 'api|db'             # last 500 lines of two services, then follow
dclt -s 10m                   # just the last 10 minutes
dclt -ot api                  # dump with timestamps, do not follow
dclt -o api | grep -i error   # pipe it — the preview stays on stderr
dclt -f prod.yml api          # custom compose file
dclt -P dev                   # include profile-gated services
```

## The preview

```
   compose logs
   docker-compose.yml
   api db
   --tail 500 --follow
   docker compose -f docker-compose.yml logs --tail 500 --follow api db
──────────────────────────────────────────────────────────────────────────
```

**No confirmation.** `dclt` only reads — it never recreates, restarts or
removes anything, so making you type `yes` to look at logs would be friction
with no payoff. The preview still earns its place: with regex patterns you want
to see what matched before the output fills the screen.

**The preview goes to stderr**, which is what makes `dclt -o api | grep error`
work — the log lines are the data, the preview is not.

## Errors

When nothing matches, `dclt` says so and lists what it could have matched:

```
  dclt: no service matched: zzz
  available: api db worker
```

| Code | When |
|---|---|
| `0` | Logs streamed and ended cleanly |
| `1` | No service matched, bad flag, bad line count, missing file |
| other | Passed straight through from `docker compose` |

## Notes

**`--env-file` and `--profile` position.** Both are options of `docker compose`
itself, so they are emitted before the `logs` subcommand — the same fix
described in [dcup.md](dcup.md).

**Long flag names in the built command.** The preview doubles as
documentation, so `dclt` emits `--tail`, `--follow` and `--timestamps` rather
than `-n`, `-f` and `-t`. It also keeps `--follow` from looking like a second
compose-file `-f`.

**Service list ordering.** `docker compose config --services` does not
guarantee an order — the same file can return `api db worker` on one run and
`worker api db` on the next. The list is sorted before use so the preview is
stable. Docker does not care what order services are passed in.

## Related

- [`dcup`](dcup.md) — bring services up
- [v2 README](../README.md) — layout and the migration contract
