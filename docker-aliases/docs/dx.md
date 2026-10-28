# `dx` — run a command inside any running container

Opens a shell in a container, or runs a command in it — any container on the
host, wherever you are standing. The host-wide twin of [`dcx`](dcx.md).

- **Source:** [`commands/dx.sh`](../commands/dx.sh)
- **Completion:** [`completions/dx.bash`](../completions/dx.bash) · [`completions/dx.zsh`](../completions/dx.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dx [flags] <pattern> [command...]
```

## Flags

| Flag | Maps to | Meaning |
|---|---|---|
| `-u <user>` | `--user` | Run as this user — `root` being the common one |
| `-w <dir>` | `--workdir` | Start in this directory |
| `-h`, `--help` | — | Show the built-in help |

**Flags go before the pattern.** Everything after the pattern is the command,
so `dx api ls -la` hands `-la` to `ls`. No short-flag clustering, for the same
reason as `dcx`: `-la` must never be readable as two `dx` options.

## Why it exists

`dcx` needs you standing in the compose project. `dx` does not — which is the
same reason [`dcd`](dcd.md) exists: you are often working on one thing and need
to poke at a container that belongs to something else.

It completes the pairing the rest of the commands already have:

| compose project | whole host |
|---|---|
| `dcps` | `dps` |
| `dclt` | `dlt` |
| `dcver` | `dver` |
| `dcx` | **`dx`** |

## Only running containers

`docker exec` cannot enter a stopped container, so `dx` only offers and matches
running ones. Listing stopped containers would only move the error from the
match to the exec, where it is harder to read.

## The shell it opens

With no command, `dx` asks the container whether it has `bash` and opens it,
falling back to `sh` — Alpine images only ship `sh`:

```bash
dx keycloak        # bash if the image has it, otherwise sh
```

The probe costs one extra round trip, and buys a preview that names the real
shell instead of a wrapper.

## One container, or an error

The pattern is a regular expression against container names. It must match
**exactly one**:

```
$ dx api ls
  dx: 'api' matched 2 containers
  fx-api
  other-api
  → narrow the pattern, or use '^fx-api$'
```

Nothing runs. You can only be inside one container, and silently choosing one
is how you type into the wrong shell.

When nothing matches, the running containers are listed **one per line** —
unlike `dcx`'s single line. A project has a handful of services; a host has
dozens of containers, and thirty names on one line is a wall.

## Stdin and the TTY

This is the one place `dx` does not simply copy `dcx`, because plain
`docker exec` behaves differently from `docker compose exec`: compose keeps
stdin and allocates a TTY by default, plain exec does neither.

| situation | what `dx` passes |
|---|---|
| terminal on both ends | `-it` — an interactive shell |
| anything else | `-i` — stdin kept open, no TTY |

`-i` is unconditional, and that matters. It is what lets this work:

```bash
cat dump.sql | dx postgres psql -U app
```

The first version gave `-i` only when stdin was a *terminal*, which is exactly
backwards — a piped command arrived at an empty stdin and nothing ran. `-i` on a
closed stdin just reads EOF, so there is no case where passing it hurts. `-t` is
the one that has to be conditional: a TTY into a pipe is what makes
`dx api ls | grep x` misbehave.

## Examples

```bash
dx keycloak                         # open a shell
dx '^nginx-base-full-nginx-1$'      # exactly that container
dx -u root grafana                  # shell in as root
dx redis redis-cli ping             # one command, then leave
dx -w /app api npm test             # run from a directory
dx api cat /etc/hosts | grep db     # pipe it — no TTY is allocated
cat seed.sql | dx db psql -U app    # feed it on stdin
```

## The preview

```
  [docker] docker exec
  [svc] keycloak
  [flags] -it
  $ docker exec -it keycloak bash
  ────────────────────────────────────────
```

On stderr, so `dx api cat file | grep x` gets only the file. No confirmation:
opening a shell changes nothing by itself, and this is used all day.

## Errors

| Situation | Message | Exit |
|---|---|---|
| No pattern | `a container pattern is required` | 1 |
| Unknown flag | `unknown flag: -z  (flags go before the pattern)` | 1 |
| `-u` / `-w` with no value | `-u requires a user` | 1 |
| Daemon unreachable | `could not reach the docker daemon` | 1 |
| Nothing running | `no containers are running` | 1 |
| No match | `no running container matched: <pattern>` + the list | 1 |
| Several matches | `'<pattern>' matched N containers` + the list | 1 |
| Ran | whatever the command inside returned | its own |

## Notes

- The pattern is a regex, so `dx api` matches `api`, `fx-api` and
  `nginx-api-ws-nginx-1`. Anchor it — `'^fx-api$'` — when the name is a
  substring of others.
- Completion offers running container names, and after the pattern it offers
  common commands. It does **not** offer `dx`'s own flags there: after the
  pattern a dash word is argv for the command inside, and `dcx` gets this wrong.

## Related

- [`dcx`](dcx.md) — the same, scoped to the compose project here
- [`dps`](dps.md) — find the container's exact name first
- [`dcd`](dcd.md) — jump to the project a container belongs to
