# docker-aliases

Docker and Docker Compose shortcuts for bash and zsh. Twenty-three commands,
each one earning its place by being used daily.

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
├── commands/<name>.sh   one file per command — the table below is the list
├── completions/         <name>.bash and <name>.zsh for each one
├── docs/<name>.md       one page per command (dcps shares dps.md)
└── tests/
    ├── cases/<name>.bats    one case file per command, plus ui, completion, resolution
    └── helpers/shim.bash    the fake docker every case runs against
```

Adding a command means dropping a file in `commands/`, its completions, a page
in `docs/` and a case file in `tests/cases/`. `init.sh` globs both
`commands/*.sh` and the completions for the running shell, and
`completion.bats` globs the commands, so none of them needs editing.

Two commands share code across files, on purpose: `dcstats` is a front for the
table in `dstats.sh`, and `devents` colours health with `dhealth.sh`'s
function. `init.sh` always loads every command, so the dependency cannot break
by load order.

## Commands

The `dc` prefix means "the compose project in this directory, by service name";
a bare `d` means "the whole host, by container name".

### The compose project you are standing in

| Command | Does | Docs |
|---|---|---|
| `dcup` | Bring compose services up | [docs/dcup.md](docs/dcup.md) |
| `dcdown` | Stop and remove services | [docs/dcdown.md](docs/dcdown.md) |
| `dcrestart` | Restart services — and say what a restart will not do | [docs/dcrestart.md](docs/dcrestart.md) |
| `dcx` | Run a command or open a shell in a service | [docs/dcx.md](docs/dcx.md) |
| `dclt` | Tail logs for services matched by regex | [docs/dclt.md](docs/dclt.md) |
| `dcps` | List this project's services | [docs/dps.md](docs/dps.md) |
| `dcver` | Which build is running in each service | [docs/dcver.md](docs/dcver.md) |
| `dcstats` | Resource use by service, against each one's limits | [docs/dcstats.md](docs/dcstats.md) |
| `dcd` | Jump to a container's compose project directory | [docs/dcd.md](docs/dcd.md) |

### The host: looking

| Command | Does | Docs |
|---|---|---|
| `dps` | List containers on this host | [docs/dps.md](docs/dps.md) |
| `dprj` | Compose projects on this host, and how much of each is up | [docs/dprj.md](docs/dprj.md) |
| `dip` | Which container has an IP, or what IP a container has | [docs/dip.md](docs/dip.md) |
| `dnet` | Networks, and what really uses each one | [docs/dnet.md](docs/dnet.md) |
| `dvol` | Volumes, who mounts them, and how big they are | [docs/dvol.md](docs/dvol.md) |
| `di` | List images, and what you could delete | [docs/di.md](docs/di.md) |
| `dver` | Which build is running, host-wide | [docs/dver.md](docs/dver.md) |
| `dstats` | Resource use, against each container's own limits | [docs/dstats.md](docs/dstats.md) |
| `dhealth` | Why a container is (un)healthy — its probe and what it printed | [docs/dhealth.md](docs/dhealth.md) |
| `devents` | What happened to a container, and why | [docs/devents.md](docs/devents.md) |
| `dlt` | Tail logs for containers matched by regex | [docs/dlt.md](docs/dlt.md) |

### The host: acting

| Command | Does | Docs |
|---|---|---|
| `dx` | Run a command or open a shell in any running container | [docs/dx.md](docs/dx.md) |
| `drestart` | Restart running containers by name | [docs/drestart.md](docs/drestart.md) |
| `dprune` | Delete what docker no longer uses, after showing exactly what | [docs/dprune.md](docs/dprune.md) |

## Testing

```bash
cd tests
./run.sh                              # this machine, bash + zsh
./run.sh bash dcup                    # one shell, one case
docker compose build && docker compose up -d
docker compose exec ubuntu24 zsh      # poke around by hand
```

769 checks per shell across 7 distros — Debian 11/12/13 and Ubuntu
20.04/22.04/24.04/26.04, covering bash 5.0→5.3 and zsh 5.8→5.9. The suite is
hermetic: `docker` is shimmed, so it asserts on the exact argv each command
would run while being unable to touch a real container. It runs on
[bats-core](https://github.com/bats-core/bats-core), one case file per command.

See [tests/README.md](tests/README.md) — including an honest account of what is
**not** covered (real `docker compose up`, and interactive zsh TAB).

## Design rules

Every command here follows these. They are why this exists in the form it does.

**Every command says what it is about to do, and no flag disables it.** The
form depends on what the command is: one that changes something renders a
preview block before acting, and one whose entire output is a table renders a
scope line instead — `docker stats · 27 of 27` — because a preview there would
say everything twice. The nine that act (`dcup` `dcdown` `dcrestart` `drestart`
`dprune` `dcx` `dx` `dclt` `dlt`) have the block; the fourteen that only read
have the line — or, for `dhealth` and `devents` on a single container, a header
naming it. This used to read "every command renders a preview", which was false
for six of the first eleven and contradicted by `lib/ui.sh` and by two of the
doc pages.

**The preview shows the real command.** Not a description of it, not a
reconstruction — the actual command line. Commands build one command as an
array, render those same pieces, and execute it, and nothing here uses `eval`.
Two honest limits. The command line is printed with `%s` and the colour
constants are real escape bytes, because it used to be `%b` over literal ones
and that ran escape processing on the user's own argv — `sed 's/a/\n/'` showed
a line break, and an argument containing `\c` silently truncated the rest of
the preview. And argv boundaries are still not round-tripped: an array cannot
survive as one string, so `sh -c 'echo a b'` renders without its quotes.

**The preview goes to stderr.** It is UI, not data. A command whose output you
pipe — `dclt -o api | grep error` — must not have its preview land in the pipe.

**Confirmation follows the blast radius, not the habit.** A command that
changes state (`dcup`) always confirms. A command that only reads (`dclt`)
never does — making someone type `yes` to look at logs is friction with no
payoff, and friction people learn to click through stops protecting anything.

**Destroying data asks a different question.** `dcdown` takes `yes`; `dcdown -v`
makes you type the project name, and names every volume it is about to delete.
`dprune`, where everything is irreversible, makes you type the docker host's
name — taken from `docker info`, so under `DOCKER_HOST` it is the remote
machine's. Not because `yes` is too short, but because `yes` is the answer to
every other prompt — repeat it enough and it stops being an answer. A prompt
that can only be satisfied by looking at the screen is the only kind that
still works.

**What a destructive preview shows is what runs.** `dprune` deletes each item
it listed by its own name, never through a prune that re-evaluates at run time,
and never with `-f` — so anything that started being used between the preview
and the answer is refused by docker instead of deleted. And it says why each
item is on the list: removing a stopped container frees its networks, images
and volumes, and a preview that only asked "what is unused now?" would miss
every one of them.

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

The same rule reaches the service lookups, for a second reason: a `$(…)` is a
subshell, so anything the function *stores* is lost as well. Every caller of
`_get_compose_services` read it that way, which silently discarded the cache on
every single call — five consecutive lookups measured 112/168/145/163/104 ms
where one should have cost anything at all, while the same function called
directly answered the second time in 18 ms. They now call
`_get_compose_services_into`, `_get_all_compose_services_into` and
`_get_compose_profiles_into` and read `_DA_R`; the wide path, which is what TAB
uses, went **234 → ~30 ms**. The printing wrappers remain, and their comments
say plainly that they forfeit the cache.

**Read a file with `$(<file)`, never `$(cat file)`.** bash and zsh both
special-case the first form and read the file inline — no subshell, no
`/bin/cat`. Measured 0.032 ms against 2.06 ms, **65 times cheaper**, and `dver`
does it once per container. One catch: `$(<file)` on a missing file prints to
stderr, and `2>/dev/null` on the assignment does **not** suppress that in bash
(zsh does). Guard with `[[ -s file ]]` instead — the redirection looks like it
works right up until you run it in the other shell.

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

**The shared flags mean the same thing everywhere.** `-f` is the compose file
in every command — never "follow". `-e` is the env file, `-P` the profile, `-o`
is *once*, which is why `dcdown` spells orphans `-O`.

Outside that shared set a letter can mean two things, and six do: `-r` is
*recreate* in `dcup` and *raw* in `dver`/`dcver`; `-p` is *pull* in `dcup` and
*print* in `dcd`; `-s` is *since* in `dclt`/`dlt` and *size* in `di`; `-u` is
*user* in `dcx` and *unused* in `di`; `-a` is *all containers* in
`dps`/`dcps`/`dlt` and *show-without-git.properties* in `dver`; `-t` is
*timestamps* in the log commands and *absolute time* in the tables. This line
claimed none of that happened. The guarantee that holds is the one above —
within a family, a letter does not move.

**Resolve files and profiles exactly as docker does.** Whatever `docker compose`
would act on in a directory, these commands act on too: the `COMPOSE_FILE` list,
the override sibling (and its deliberate absence when an explicit list disables
it), and `COMPOSE_PROFILES` — including that `-P` *replaces* it rather than
adding to it. Diverging by one file or one profile means the preview describes
something docker is not about to do.

**Two questions about services, and they get two functions.** `config
--services` answers *what would docker act on under these profiles* — with none
active, only the profile-less services. That is the right answer for `dcup`'s
preview, where naming nothing means docker starts exactly those. It is the wrong
answer everywhere else: `dclt`, `dcx`, `dcver` and `dcdown` match a pattern
against service names, and `logs`, `exec` and `down` do not filter by profile at
all — naming a service activates its own profile. So those four, and every
completion, ask `_get_all_compose_services` instead, which widens to every
declared service unless the user narrowed it with `-P`.

The cost of getting this backwards was measured in both directions. Using the
narrow list to match made `dclt suitems` answer *"no service matched"* about a
running container, in a project where three of seventeen services have no
profile. Using the wide list in `dcup`'s preview would promise seventeen
services and start three — a preview that overstates the action, which this
README forbids above.

**Join on the separator the splitter expects.** Profiles live in an array and
reach `_get_compose_services` as one string. Flattening with `"${profiles[*]}"`
joins on a space while `_split_commas` only splits on a comma, so `-P dev -P
full` asked compose for a profile named `"dev full"` — no such profile, no
error, and the answer silently fell back to the profile-less list. `_join_commas`
exists so the two halves agree, and the completions never had the bug because
`_profiles_from_words` had been joining on commas all along.

**Nothing beyond a POSIX shell and coreutils.** `sd`, `rg`, `jq` and friends are
excellent and none of them is on a fresh Debian server, which is where these
aliases get used.

A guard test enforces it — and for a long time it did not. Its pattern required
the tool to follow start-of-line, `;`, `&`, `|`, `(`, a backtick or `$(`, so
`if jq …`, `then rg …`, `do sd …`, `! rg …`, `xargs fd …` and a `| jq` at end of
line all walked past it. Falsified by planting seven forms: six escaped, and the
only one caught was a tool at the very start of a line — which is exactly the
shape the `sd` that originally slipped into `dcver` happened to have. The guard
now asks whether the token is a command word, and a positive control plants a
violation and fails if the detector stays quiet.

**A test that cannot fail is not a test.** The suite runs with
`DOCKER_ALIASES_NERD_FONT=0`, so for a long time it never executed the Nerd Font
branch at all — and that branch shipped completely broken behind a wall of green
checks. Whenever a mode exists, something has to exercise it.

The same shape turned up twice more, so it is worth stating as a method rather
than a warning. `DOCKER_ALIASES_CACHE_TTL=0` in the test helpers disabled the
service cache, which is how a cache that never once worked sat behind green
checks for months. And the forbidden-tool guard above caught one form in seven.
Both were found the same way: **plant the regression and watch the test go
red.** A new test earns its place only after it has been seen to fail, and a
test whose subject has a mode has to name which mode it is in. Where a check
could pass for the wrong reason, add the positive control next to it — the
suite now has three, and each one fails if its detector goes quiet.

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
| `DOCKER_ALIASES_LOG_LINES` | `100` | Default `-n` for `dclt` and `dlt` |
| `DOCKER_ALIASES_GIT_PROPS` | — | Extra `git.properties` paths for `dcver`, `:`-separated |
