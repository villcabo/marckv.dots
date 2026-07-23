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
├── commands/
│   └── dcup.sh          one file per command
├── completions/
│   ├── dcup.bash
│   └── dcup.zsh
└── docs/
    └── dcup.md          one page per command
```

Adding a command means dropping a file in `commands/`, its completions, and a
page in `docs/`. `init.sh` picks up `commands/*.sh` automatically.

## Commands

| Command | Does | Docs |
|---|---|---|
| `dcup` | Bring compose services up | [docs/dcup.md](docs/dcup.md) |

## Testing

```bash
cd tests
./e2e.sh                              # this machine, bash + zsh
docker compose build && docker compose up -d
docker compose exec ubuntu24 zsh      # poke around by hand
```

98 checks per shell across 7 distros — Debian 11/12/13 and Ubuntu
20.04/22.04/24.04/26.04, covering bash 5.0→5.3 and zsh 5.8→5.9. The suite is
hermetic: `docker` is shimmed, so it asserts on the exact argv `dcup` would run
while being unable to touch a real container.

See [tests/README.md](tests/README.md) — including an honest account of what is
**not** covered (real `docker compose up`, and interactive zsh TAB).

## Design rules

Every command in v2 follows these. They are the reason v2 exists.

**The preview is mandatory.** Any command that changes state renders what it is
about to do and waits. No flag disables it.

**The preview shows the real command.** Not a description of it, not a
reconstruction — the actual command line. Commands build one command as an
array, render those same pieces, and execute it. No `eval`, so quoting can
never make the preview lie.

**Confirmation takes the full word `yes`.** A bare `y` is rejected. Plain Enter
cancels. These commands recreate and restart running services; one keystroke is
too cheap.

**No `-y` flag.** `DOCKER_ALIASES_AUTO_YES=1` exists for tests and CI only. An
env var is much harder to fire by accident than a mistyped flag.

**bash and zsh, equally.** Every command is verified in both. The traps that
already bit us, kept here so they don't bite twice:

- zsh does **not** word-split unquoted parameters. `for f in $files` silently
  collapses to one item. Iterate over arrays or read line by line.
- `${var,,}` (lowercase) and `IFS=, read -ra` are bash-only and break in zsh.
- Arrays are 0-indexed in bash and 1-indexed in zsh. Never index — iterate.
- `COLUMNS` is unset or `0` in a non-interactive shell. Fall back, don't clamp.

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `DOCKER_COMPOSE_FILE` | — | Explicit compose file, wins over detection |
| `DOCKER_ALIASES_NERD_FONT` | `1` | `0` forces ASCII icons |
| `DOCKER_ALIASES_CACHE_TTL` | `5` | Service-list cache seconds, `0` disables |
| `DOCKER_ALIASES_AUTO_YES` | `0` | `1` bypasses confirmation. **Tests/CI only** |
