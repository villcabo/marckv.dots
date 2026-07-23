# docker-aliases v2

A deliberately small rebuild of `docker-aliases/`, grown one command at a time.
Only commands that get used daily earn a place here.

## Migration contract

**This directory is a migration, not a fork.** The name `v2` is temporary and
must not outlive the transition.

| Phase | State |
|---|---|
| Now | `docker-aliases/` stays installed and is what you use daily. `docker-aliases-v2/` is built and tested alongside it. |
| Cutover | Once v2 covers the commands you actually use: delete `docker-aliases/`, rename `docker-aliases-v2/` → `docker-aliases/`, repoint the installer. |
| After | One directory. No `v2` anywhere. |

Two rules keep this from rotting into two competing toolkits:

1. **Never source both at once.** A shell function can only be defined once —
   `dcup` from whichever file loaded last silently wins, and you have no way to
   tell which one ran.
2. **v1 is never patched again.** Fixes land in v2. If something in v1 is
   broken badly enough to matter, that is a signal to port the command, not to
   maintain two copies.

Nothing is being preserved by keeping v1 on disk — it lives in git history on
the `feature/docker-aliases` branch. It stays only so your daily workflow keeps
working while v2 is built.

## Install

```bash
source /path/to/docker-aliases-v2/init.sh
```

The loader resolves its own directory, so it works from anywhere and from
either bash or zsh.

## Layout

```
docker-aliases-v2/
├── init.sh              entry point — sources everything in order
├── lib/
│   ├── ui.sh            colors, icons, preview renderer, confirmation
│   └── compose.sh       compose file detection, service/profile discovery
├── commands/            one file per command
│   ├── dcup.sh
│   ├── dclt.sh
│   ├── dcdown.sh
│   ├── dcx.sh
│   ├── dcd.sh
│   ├── dps.sh
│   └── dcps.sh
├── completions/         one pair per command
│   ├── dcup.bash / dcup.zsh
│   ├── dclt.bash / dclt.zsh
│   ├── dcdown.bash / dcdown.zsh
│   ├── dcx.bash / dcx.zsh
│   ├── dcd.bash / dcd.zsh
│   ├── dps.bash / dps.zsh
│   └── dcps.bash / dcps.zsh
├── docs/                one page per command
│   ├── dcup.md
│   ├── dclt.md
│   ├── dcdown.md
│   ├── dcx.md
│   ├── dcd.md
│   └── dps.md          (dcps.md links here)
└── tests/               e2e across 7 distros and both shells
```

Adding a command means dropping a file in `commands/`, its completions, and a
page in `docs/`. `init.sh` globs both `commands/*.sh` and the completions for
the running shell, so it never needs editing.

## Commands

| Command | Does | Docs |
|---|---|---|
| `dcup` | Bring compose services up | [docs/dcup.md](docs/dcup.md) |
| `dclt` | Tail logs for services matched by regex | [docs/dclt.md](docs/dclt.md) |
| `dcdown` | Stop and remove services | [docs/dcdown.md](docs/dcdown.md) |
| `dcx` | Run a command or open a shell in a service | [docs/dcx.md](docs/dcx.md) |
| `dcd` | Jump to a container's compose project directory | [docs/dcd.md](docs/dcd.md) |
| `dps` | List containers on this host | [docs/dps.md](docs/dps.md) |
| `dcps` | List this project's services | [docs/dps.md](docs/dps.md) |

## Testing

```bash
cd tests
./e2e.sh                              # this machine, bash + zsh
docker compose build && docker compose up -d
docker compose exec ubuntu24 zsh      # poke around by hand
```

430 checks per shell across 7 distros — Debian 11/12/13 and Ubuntu
20.04/22.04/24.04/26.04, covering bash 5.0→5.3 and zsh 5.8→5.9. The suite is
hermetic: `docker` is shimmed, so it asserts on the exact argv each command
would run while being unable to touch a real container.

See [tests/README.md](tests/README.md) — including an honest account of what is
**not** covered (real `docker compose up`, and interactive zsh TAB).

## Design rules

Every command in v2 follows these. They are the reason v2 exists.

**The preview is mandatory.** Every command renders what it is about to do
before doing it. No flag disables it.

**The preview shows the real command.** Not a description of it, not a
reconstruction — the actual command line. Commands build one command as an
array, render those same pieces, and execute it. No `eval`, so quoting can
never make the preview lie.

**The preview goes to stderr.** It is UI, not data. A command whose output you
pipe — `dclt -o api | grep error` — must not have its preview land in the pipe.

**Confirmation follows the blast radius, not the habit.** A command that
changes state (`dcup`) always confirms. A command that only reads (`dclt`)
never does — making someone type `yes` to look at logs is friction with no
payoff, and friction people learn to click through stops protecting anything.

**Destroying data asks a different question.** `dcdown` takes `yes`; `dcdown -v`
makes you type the project name, and names every volume it is about to delete.
Not because `yes` is too short, but because `yes` is the answer to every other
prompt — repeat it enough and it stops being an answer. A prompt that can only
be satisfied by looking at the screen is the only kind that still works.

**Confirmation takes the full word `yes`.** A bare `y` is rejected. Plain Enter
cancels. These commands recreate and restart running services; one keystroke is
too cheap.

**No `-y` flag.** `DOCKER_ALIASES_AUTO_YES=1` exists for tests and CI only. An
env var is much harder to fire by accident than a mistyped flag.

**Variants are a smell.** v1 had `dps`, `dps1` and `dpsp` — three commands
because the ports column overflowed the row. Nobody wanted three views; they
wanted one that fit. When a command sprouts variants, fix what made them
necessary and the variants delete themselves.

**Shorten visibly, never invisibly.** When a value must be cut to fit, the cut
is shown (`cross-border-st…support-1`). Silently dropping a redundant prefix
would read better and would produce a name that looks real, is not, and fails
when pasted into `docker exec`.

**Secrets are never printed.** `docker inspect` hands over environment
variables freely, and in a real project those are database passwords and API
tokens. `dcd` shows everything else and no flag turns them on — a scrollback is
a lasting place to leave a credential.

**Guessing is not a feature.** When a pattern is ambiguous and the command can
only act on one thing, `dcx` lists the matches and stops. Silently taking the
first is how you end up typing into the wrong container — and not noticing.

**Flags mean the same thing everywhere.** `-f` is the compose file in every
command — never "follow". `-e` is the env file, `-P` the profile. A letter is
never reused for a second meaning: `-o` is *once* in `dclt`, so `dcdown` spells
orphans `-O`, and anything that would collide is long-form only.

**bash and zsh, equally.** Every command is verified in both. The traps that
already bit us, kept here so they don't bite twice:

- zsh does **not** word-split unquoted parameters. `for f in $files` silently
  collapses to one item. Iterate over arrays or read line by line.
- `${var,,}` (lowercase) and `IFS=, read -ra` are bash-only and break in zsh.
- Arrays are 0-indexed in bash and 1-indexed in zsh. Never index — iterate.
- `COLUMNS` is unset or `0` in a non-interactive shell. Fall back, don't clamp.
- `status` is **read-only in zsh** (it is zsh's name for `$?`). Assigning it
  aborts the whole function. Same trap: `path`, `argv`, `options`.
- `${var:+$'\n'}` does not expand the `$'...'` inside the substitution in zsh.
  Put the newline in a plain variable first.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `DOCKER_COMPOSE_FILE` | — | Explicit compose file, wins over detection |
| `DOCKER_ALIASES_NERD_FONT` | `1` | `0` forces ASCII icons |
| `DOCKER_ALIASES_CACHE_TTL` | `5` | Service-list cache seconds, `0` disables |
| `DOCKER_ALIASES_AUTO_YES` | `0` | `1` bypasses confirmation. **Tests/CI only** |
