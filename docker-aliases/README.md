# docker-aliases

Docker and Docker Compose shortcuts for bash and zsh. Nine commands, each one
earning its place by being used daily.

Every command previews what it is about to do — naming the exact command it will
run — before running it, and asks before anything that changes state.

## Install

```bash
cd installer && ./02-install-docker-aliases.sh
```

That adds one source line to `~/.bash_aliases`. The commands are shell functions
read straight from this directory, so editing them here takes effect in the next
shell with nothing to re-run.

By hand, if you prefer:

```bash
source ~/.marckv.dots/docker-aliases/init.sh
```

The loader resolves its own directory, so it works from anywhere and from either
shell. **zsh must source it after `compinit`**, or compinit wipes the
completions.

## History

This directory replaced an earlier version of itself in July 2026. The old one
is in git — `git log --follow` reaches it, and the branch
`feature/docker-aliases` holds the whole rebuild commit by commit.

It is not on disk on purpose. Two sets of these commands cannot coexist: a shell
function is defined once, so whichever loaded last silently wins and you have no
way to tell which one ran.

Things that changed and are worth knowing:

- `-e` (env file) never worked in the old version — it emitted `--env-file`
  after `up`, where docker rejects it.
- `docker-compose.override.yml` was silently dropped whenever `-f` was passed,
  which is always.
- `COMPOSE_FILE` was ignored, so a project split across five files acted on one.
- `dps` / `dps1` / `dpsp` and `dcps` / `-c` / `-p` collapsed into `dps` and
  `dcps`: four of those six existed only to dodge an overflowing ports column.
- `dcpr` became [`dcver`](docs/dcver.md), which reads `app.version` and flags
  builds made from a dirty tree.
- `docker-color-output` is no longer used at all.

## Layout

```
docker-aliases/
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
│   ├── dcps.sh
│   ├── dcver.sh
│   ├── dver.sh
│   └── di.sh
├── completions/         one pair per command
│   ├── dcup.bash / dcup.zsh
│   ├── dclt.bash / dclt.zsh
│   ├── dcdown.bash / dcdown.zsh
│   ├── dcx.bash / dcx.zsh
│   ├── dcd.bash / dcd.zsh
│   ├── dps.bash / dps.zsh
│   ├── dcps.bash / dcps.zsh
│   ├── dcver.bash / dcver.zsh
│   ├── dver.bash / dver.zsh
│   └── di.bash / di.zsh
├── docs/                one page per command
│   ├── dcup.md
│   ├── dclt.md
│   ├── dcdown.md
│   ├── dcx.md
│   ├── dcd.md
│   ├── dps.md          (dcps.md links here)
│   ├── dcver.md
│   ├── dver.md
│   └── di.md
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
| `dcver` | Which build is running in each service | [docs/dcver.md](docs/dcver.md) |
| `dver` | Which build is running, host-wide | [docs/dver.md](docs/dver.md) |
| `di` | List images, and what you could delete | [docs/di.md](docs/di.md) |

## Testing

```bash
cd tests
./run.sh                              # this machine, bash + zsh
./run.sh bash dcup                    # one shell, one case
docker compose build && docker compose up -d
docker compose exec ubuntu24 zsh      # poke around by hand
```

357 checks per shell across 7 distros — Debian 11/12/13 and Ubuntu
20.04/22.04/24.04/26.04, covering bash 5.0→5.3 and zsh 5.8→5.9. The suite is
hermetic: `docker` is shimmed, so it asserts on the exact argv each command
would run while being unable to touch a real container. It runs on
[bats-core](https://github.com/bats-core/bats-core), one case file per command.

See [tests/README.md](tests/README.md) — including an honest account of what is
**not** covered (real `docker compose up`, and interactive zsh TAB).

## Design rules

Every command here follows these. They are why this exists in the form it does.

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

**Nothing forks inside a per-row loop.** `x=$(helper …)` is not a function
call — it is a `fork()`: the shell clones itself, runs the helper in the copy,
reads the answer back through a pipe and reaps the child. Measured here: **0.50
ms every time**, no matter how trivial the helper. `dps` used to spend 19 of
those per container — three in the collect loop, three more inside
`_compact_ports` (one of them an `exec` of `/usr/bin/tr` just to split on
commas), two inside `_short_status`, and **eleven in the renderer**, which
recomputed `IMAGE is cyan` once per row for thirteen rows. Ninety percent of a
104 ms `dps` was that, and none of it was docker.

So helpers on a per-row path come in two forms: `_thing_into` assigns to
`_DA_R` and prints nothing, `_thing` is a one-line wrapper that prints it.
Loops call the `_into` form; everything else keeps the printed one, so the
contract the tests check never moved. Constants get resolved once above the
loop, not inside it. `dps` went 104 → 21 ms, `dps -a` 201 → 27 ms, with the
output byte-identical in both shells.

**Do not reach for `printf "%-*s"` to pad a column.** bash pads that by
**bytes** and zsh by **characters**. A port rendered `3001→3000` is 9
characters and 11 bytes, so the column lands two short in bash and correct in
zsh — and every mapped port and health glyph in these tables is multibyte.
Pad on `${#text}`, which counts characters in both.

**Shorten visibly, or not at all.** When a value must be cut, the cut is shown.
Better still, arrange the table so nothing has to be: `dps` follows `docker ps`'s
column order, which puts the identifier LAST — and a last column needs no
padding, so images and names both stay whole.

**Host and project are the same command twice.** `dps`/`dcps` and
`dver`/`dcver` ask one question at two scopes, and the `dc` prefix always means
"this compose project". Learning one teaches the other.

**Hide only what you can account for.** `dver` drops containers with no version
— but the header still counts them, the footer names them, and `-a` brings them
back. An omission you can check is a filter; one you cannot is a lie.

**Borrow the order people already know.** `dps` lays its columns out exactly as
`docker ps` does. Muscle memory beats any ordering we could invent.

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

**Resolve files and profiles exactly as docker does.** Whatever `docker compose`
would act on in a directory, these commands act on too: the `COMPOSE_FILE` list,
the override sibling (and its deliberate absence when an explicit list disables
it), and `COMPOSE_PROFILES` — including that `-P` *replaces* it rather than
adding to it. Diverging by one file or one profile means the preview describes
something docker is not about to do.

**Nothing beyond a POSIX shell and coreutils.** `sd`, `rg`, `jq` and friends are
excellent and none of them is on a fresh Debian server, which is where these
aliases get used. A guard test enforces it.

**A test that cannot fail is not a test.** The suite runs with
`DOCKER_ALIASES_NERD_FONT=0`, so for a long time it never executed the Nerd Font
branch at all — and that branch shipped completely broken behind a wall of green
checks. Whenever a mode exists, something has to exercise it.

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
- An unquoted `(` inside an expansion **pattern** opens a glob group in zsh:
  `${s%% (*}` is an unterminated one and aborts. bash reads it as an ordinary
  character. Quote the literal part — `${s%%" ("*}`.
- Indirect array expansion has no portable form: `${!v[@]}` in bash, `${(P)v}`
  in zsh. Pass rows as delimited text instead of arrays by name.
- Nerd Font glyphs live in the Private Use Area and do **not** survive every
  editor or transfer — write them as `\uXXXX` escapes, never as literal
  characters. This file once shipped with every glyph silently emptied, and a
  blank icon is indistinguishable from one the terminal cannot draw.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `COMPOSE_FILE` | — | **docker's own**: `:`-separated list of compose files |
| `COMPOSE_PATH_SEPARATOR` | `:` | What separates the entries in `COMPOSE_FILE` |
| `COMPOSE_PROFILES` | — | **docker's own**: profiles to enable. `-P` replaces it |
| `DOCKER_COMPOSE_FILE` | — | A v1 invention, a single file. Kept for compatibility |
| `DOCKER_ALIASES_NERD_FONT` | `1` | `0` forces ASCII icons |
| `DOCKER_ALIASES_CACHE_TTL` | `5` | Service-list cache seconds, `0` disables |
| `DOCKER_ALIASES_AUTO_YES` | `0` | `1` bypasses confirmation. **Tests/CI only** |
| `DOCKER_ALIASES_GIT_PROPS` | — | Extra `git.properties` paths for `dcver`, `:`-separated |
