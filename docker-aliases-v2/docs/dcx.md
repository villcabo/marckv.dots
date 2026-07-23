# `dcx` — run a command inside a Compose service

Opens a shell in a service, or runs a command in it. Figures out which shell the
container actually has, and refuses to guess which container you meant.

- **Source:** [`commands/dcx.sh`](../commands/dcx.sh)
- **Completion:** [`completions/dcx.bash`](../completions/dcx.bash) · [`completions/dcx.zsh`](../completions/dcx.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcx [flags] <pattern> [command...]
```

## Flags

| Flag | Maps to | Meaning |
|---|---|---|
| `-u <user>` | `--user` | Run as this user — `root` being the common one |
| `-w <dir>` | `--workdir` | Start in this directory |
| `-f <file>` | `-f` | Compose file to use. Repeatable |
| `-e <file>` | `--env-file` | Env file to use. Repeatable |
| `-P <profile>` | `--profile` | Compose profile. Repeatable, or comma-separated |
| `-h`, `--help` | — | Show the built-in help |

**Flags go before the pattern.** Everything after the pattern is the command,
so `dcx api ls -la` passes `-la` to `ls` rather than tripping over it. This is
also why `dcx` has no clustered short flags — `-la` must never be readable as
two `dcx` options.

## The shell it opens

With no command, `dcx` asks the container whether it has `bash` and opens it,
falling back to `sh`:

```bash
dcx api        # bash if the image has it, otherwise sh
```

This exists to delete a daily annoyance. Alpine images ship no bash, so v1 went:

```
$ dcx api bash
OCI runtime exec failed: exec: "bash": executable file not found
$ dcx api sh      # ...and you retype it
```

The probe costs one extra round trip. It buys a preview that names the real
shell — `exec api bash` — instead of an `sh -c 'command -v bash && exec bash ||
exec sh'` wrapper that would technically be one call but that nobody wants to
read in a preview. Passing an explicit command skips the probe entirely.

## One service, or an error

Patterns are regular expressions, as in [`dclt`](dclt.md) and
[`dcdown`](dcdown.md) — but here they must resolve to **exactly one** service:

```
$ dcx api
  dcx: 'api' matched 2 services
  api api-worker
  → narrow the pattern, or use '^api$'
```

Two matches is an error, not a coin flip. You can only be inside one container,
and silently picking the first — what v1's `dcq` did — is how you end up typing
into the wrong shell and not noticing for a while.

```bash
dcx '^api$'    # exactly api, never api-worker
```

## The TTY is handled for you

`docker compose exec` allocates a pseudo-TTY by default, which corrupts output
the moment you pipe it. `dcx` checks whether both ends are terminals and adds
`--no-tty` when they are not:

```bash
dcx api cat /etc/hosts | grep db     # just works
```

## Examples

```bash
dcx api                           # shell in
dcx '^api$'                       # exactly this service
dcx api ls -la /app               # a command with its own flags
dcx -u root api                   # shell in as root
dcx -u root api apk add curl      # install something
dcx -w /app api npm test          # run from a directory
dcx -f prod.yml api               # custom compose file
```

## The preview

```
   compose exec
   docker-compose.yml
   api
   --no-tty --user root
   docker compose -f docker-compose.yml exec --no-tty --user root api bash
──────────────────────────────────────────────────────────────────────────
```

**No confirmation.** Opening a shell changes nothing by itself, and this is a
command you reach for dozens of times a day — a prompt here would be pure tax.
What the preview is for is telling you *which* container you are about to land
in, and as *whom*, before the prompt changes under you.

## Errors

| Code | When |
|---|---|
| `0` | The command ran (its own exit code passes through) |
| `1` | No match, several matches, missing pattern, bad flag, missing file |
| other | Passed straight through from `docker compose` |

## Notes

**`dcq` from v1 is redundant now.** It did "exec into the first service matching
a pattern". `dcx` does the same matching, but shows you the choice instead of
making it silently.

**Interactive TTY behavior is not covered by the test suite.** The suite always
runs without a terminal, so it can only assert that `--no-tty` *is* added when
there is no TTY. That a real terminal gets a real TTY is a manual check.

## Related

- [`dcup`](dcup.md) — bring services up
- [`dclt`](dclt.md) — tail logs
- [`dcdown`](dcdown.md) — stop and remove services
- [v2 README](../README.md) — layout and the migration contract
