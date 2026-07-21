# Docker Aliases — Overhaul PRD

> Working doc. Iterate here before launching `/sdd-new`.

## 1. Why

The current `docker-aliases/` has grown to ~24 `d` subcommands + ~24 `dc` subcommands + 10 standalone functions. Many are unused, redundant, or duplicate native Docker behavior. Modern compose features are missing entirely:

- **No profiles** (`--profile`) — core compose feature for env-specific service sets
- **No watch** (`docker compose watch`) — file-sync dev loop
- **No swarm support** — user wants this
- **Autocomplete is partial** — doesn't feel like native `docker compose <TAB>`
- **Previews are verbose** — user wants minimal + icon-driven

This PRD proposes a triage, new surface area, and UX redesign.

## 2. Goals / Non-goals

**Goals**
- Cut surface area to ~50% of current command count without losing daily-driver UX.
- First-class support for compose profiles, watch, run, env-file overrides.
- Add a `ds*` namespace for Docker Swarm.
- Autocomplete that feels indistinguishable from `docker compose <TAB>` (services, profiles, flags with descriptions).
- Minimalist Nerd-Font-icon previews with graceful fallback to ASCII when no Nerd Font.

**Non-goals**
- Replacing `docker` / `docker compose` directly — passthrough stays.
- Cross-shell support beyond bash + zsh.
- Plugin system. Keep modules in `docker-aliases/*.sh` flat.
- Docker Desktop / VS Code integrations.

## 3. Triage — current commands

### KEEP (user-confirmed essentials)

| Command | Why |
|---|---|
| `dcps` | Daily driver — service list |
| `dcup` | Daily driver — start with preview/confirm |
| `dcdown` | Daily driver — stop+remove with confirm |
| `dclt` | **Killer feature** — follow logs by pattern (regex/literal) |
| `dcx` | Daily driver — exec into service |
| `dq` / `dcq` | Quick exec by name pattern |
| `dip` | Unique — find/list by container IP |
| `dstatus` | Overview of containers + compose services |
| `dcpr` | Niche but user-named — `git.properties` from Spring/nginx apps |

### MERGE — collapse variants into flags

| Today | Tomorrow | Notes |
|---|---|---|
| `l100`, `l300`, `l500` (×2 for d/dc) | `dclt -n <N>` (default 100) | One source of truth; `dclt` becomes the only smart-logs entry |
| `dc ul` | `dcup -l` | `-l` already follows logs |
| `dc s1`, `d s1` | `dcs --once` / `ds --once` | Snapshot via flag |
| `dc ps1`, `dc psp`, `dc p1` | `dcps -c` (compact), `dcps -p` (ports) | Flags on `dcps` |
| `d prune/prunea/pruneima/prunevol/prunenet` | `dprune [--all\|--images\|--volumes\|--networks]` | One command, scoped via flag |
| `dcleanup` | drop → use `dprune --all` | Pure duplicate |
| `d ps`/`d images`/`d stats` from the `d` dispatcher | promote to flat `dps`/`di`/`ds` | The `d <subcmd>` dispatcher adds indirection without value |

### DROP — rarely used, low ROI

| Command | Replacement / reason |
|---|---|
| `d top` | `docker top <ct>` works fine; covered by `dstats` |
| `d kill` | `docker kill` — flat-out destructive, no shortcut needed |
| `d rmi` | `docker rmi` direct |
| `d inspect` | passthrough is enough |
| `dockerhelp` | Redundant trampoline (just print "use dhelp/dchelp") |
| `dc default` subcommand | Move under `dc info` (read-only) + env var only. Setting via `.env` mutation is a foot-gun (writes to user's project `.env`) |

### RENAME — for consistency

| Today | Tomorrow | Reason |
|---|---|---|
| `d` dispatcher (24 subcmds) | drop the dispatcher | Flat aliases compose better with tab-complete |
| `dcq` (compose quick) | keep | Asymmetric with `dq` but well-known to user |

### The `d` dispatcher — hybrid model (decided)

Keep both surfaces:
- **Dispatcher** (`d <subcmd>`) — discoverability via `d <TAB>` and `d help`. Targets occasional users.
- **Flat aliases** (`dps`, `dl`, `dx`, …) — speed. Targets daily drivers.

The pair must stay in sync: every flat alias has a matching `d` subcommand and vice versa. Anything that exists in only one of the two is a smell.

Drop flat aliases for rarely-used commands (no `dtop`, `dkill`, `drmi`, `dinspect`). For those, the dispatcher is the only entry.

## 4. New surface area

### 4.1 Compose profiles

Compose v2 supports `services.<svc>.profiles: [dev, debug, ...]`. Today our aliases silently ignore them.

```bash
dcup -P dev               # equivalent to docker compose --profile dev up -d
dcup -P dev,debug         # multiple
dcup -P dev api worker    # profile + specific services
dcps -P dev               # list services in profile only
```

`-P` is short for `--profile`. Completion suggests profiles parsed from `_get_compose_profiles()` (new helper).

### 4.2 Compose watch

```bash
dcw                       # docker compose watch (default project)
dcw api                   # watch a single service
dcw -f dev.yml            # custom file
```

`dcw` follows the `-f`/`-P` flag conventions of `dcup`.

### 4.3 Compose run (one-shot)

```bash
dcrun api bash            # docker compose run --rm api bash
dcrun -P dev migrate npm run migrate
```

`--rm` is implicit (cleanup ephemeral). Pass `--no-rm` to override.

### 4.4 Env-file overrides

```bash
dcup --env-file .env.prod
dcup -e .env.prod         # short form
```

`-e` works because compose's own `-e` (set var on `exec`) is on a different command.

### 4.5 Build with bake

```bash
dcb api                   # docker compose build api (current behavior)
dcb --bake api            # docker buildx bake api — parallel, multi-target, multi-arch
```

`bake` is opt-in via `--bake`. Falls through to `docker buildx bake -f <compose-file> <targets...>`. Useful for monorepos with many images, multi-arch releases, or when compose builds become the bottleneck.

### 4.6 Swarm namespace — `ds*`

Naming conflict: today `ds` = `docker stats`. **Proposal**: rename stats to `dstats` and free up `ds*` for swarm.

| Command | What it does |
|---|---|
| `dss` | `docker stack ls` |
| `dssps <stack>` | `docker stack ps <stack>` — tasks of a stack |
| `dssdeploy <stack> [-c file]` | `docker stack deploy -c <file> <stack>` (auto-detect compose file like `dc`) |
| `dssrm <stack>` | `docker stack rm <stack>` (with confirm preview) |
| `dssvc` | `docker service ls` |
| `dssvcps <svc>` | `docker service ps <svc>` |
| `dssvcl <svc>` | `docker service logs --tail 100 -f <svc>` |
| `dssvcsc <svc>=N` | `docker service scale <svc>=N` (with preview/confirm) |
| `dssnodes` | `docker node ls` |
| `dsstatus` | overview: stacks + services + nodes |

Prefix locked: **`dss*`** (Docker Swarm Stack). `ds` (was: docker stats) is renamed to `dstats` to free the prefix.

## 5. Autocomplete redesign

### Goal

After typing `dcup <TAB>`, behave like `docker compose up <TAB>`:
- Shows **services**, **flags with descriptions**, **profiles** (when `-P` is in context).
- Tab-cycles through choices with descriptions visible (zsh `_describe`).

### Bash

Bash completion can't show descriptions, but can:
- Use `compopt -o nospace` for multi-word completions.
- Source the **official docker completion** (`docker completion bash`) and **wrap** it for our aliases so `dcup foo<TAB>` falls through to the real compose service completer.
- Cache `_get_compose_services` results per-directory (TTL 5s) — current implementation runs `docker compose config --services` on every tab, which is slow on big projects.

### Zsh

- Use `_arguments` with `_alternative` blocks to mix flags + services + profiles.
- Hook into compose's own completion when available (`docker completion zsh`).
- Add `_describe` entries for every flag (`-P[Compose profile]:profile:->profiles`).
- For `dssdeploy <stack>` completion → list stacks via `docker stack ls --format '{{.Name}}'`.

### New helpers (in `_init.sh`)

```bash
_get_compose_profiles()   # parse profiles from active compose file
_get_compose_envs()       # list .env* files in cwd
_get_swarm_stacks()       # docker stack ls --format
_get_swarm_services()     # docker service ls --format
_cache_completion()       # 5s TTL cache wrapper for slow lookups
```

## 6. Preview / UX redesign

### Current preview (verbose)

```
DOCKER COMPOSE UP 🐳
Action: Start services
Compose file: docker-compose.yml
Options: --build
Affected services: api worker db
After up: Show logs

Continue with operation? [yes/N]:
```

### Proposed (minimal + Nerd icons)

```
   compose up
   docker-compose.yml
   dev
   api  worker  db
   --build  --pull
─
  Continue? [y/N] 
```

Icons used (Nerd Font codepoints — fall back to ASCII if `tput civis` unavailable or `NO_NERD_FONT=1`):

| Glyph | Codepoint | Meaning |
|---|---|---|
|  | `` (`nf-linux-docker`) | Docker |
|  | `` (`nf-fa-file_text`) | Compose file |
|  | `` (`nf-fa-tag`) | Profile |
|  | `` (`nf-fa-server`) | Services |
|  | `` (`nf-fa-cog`) | Flags |
|  | `` (`nf-fa-question_circle`) | Confirm |

### Color palette

Single accent color per action (no rainbow):
- `up` → green (` `)
- `down` → red (`  `)
- `build` → cyan (`  `)
- `watch` → magenta (`  `)
- `prune` → yellow (`  `)
- `swarm deploy` → blue (`  `)

Trim trailing emoji clutter (`🐳`/`🛑`/`✅`) — the Nerd icon already telegraphs the action.

### Confirmation

- Prompt on `up`/`down`/`prune`/`dssrm`/`dssvcsc` (scale).
- Read-only commands (`ps`, `logs`, `stats`, `exec`, `info`) never prompt.
- New flag `-y` → skip confirm for the current invocation.
- New env var `DOCKER_ALIASES_AUTO_YES=1` → never prompt at all.

## 7. Configuration

| Env var | Purpose | Default |
|---|---|---|
| `DOCKER_COMPOSE_FILE` | Override compose file (kept) | unset |
| `DOCKER_ALIASES_NERD_FONT` | `0` to force ASCII | auto-detect |
| `DOCKER_ALIASES_AUTO_YES` | Skip all confirmations | `0` |
| `DOCKER_ALIASES_LOG_LINES` | Default tail for `dclt` | `100` |
| `DOCKER_ALIASES_CACHE_TTL` | Completion cache TTL (seconds) | `5` |

Drop the `dc default <file>` write-to-`.env` behavior. `DOCKER_COMPOSE_FILE` env var is enough.

## 8. Decisions (resolved)

1. **`d` dispatcher**: hybrid — keep dispatcher (`d ps`, `d logs`) for discoverability **and** keep flat aliases (`dps`, `dl`) for speed. Drop redundant flat aliases for rarely-used subcommands (no `dtop`, `dkill`).
2. **`bake`**: flag on `dcb` — `dcb --bake [target...]` invokes `docker buildx bake`. No separate command; the flag-based form keeps the surface tight while exposing the modern build path when needed.
3. **Swarm prefix**: `dss*`.
4. **Confirmation on `dcup`**: keep mandatory (parity with `dcdown`/`dprune`/`dss rm`). Skippable via `-y` or `DOCKER_ALIASES_AUTO_YES=1`.
5. **`dcpr` (git.properties)**: moves to `docker-aliases/extra/git-properties.sh` — opt-in by sourcing it explicitly from `~/.bashrc`/`~/.zshrc`.
6. **Backwards compatibility**: **break clean**. No deprecated wrappers. Old aliases (`dc ul`, `dc s1`, `d prunea`, `dcleanup`, etc.) simply disappear in the first release after the overhaul.
7. **File layout**: see §9.

## 9. File layout

```
docker-aliases/
├── _init.sh                 # colors + Nerd icons + helpers (_get_*, _confirm, completion cache)
├── docker.sh                # d dispatcher + dps/di/dl/dx/dstats/dprune + dq/dip
├── compose-core.sh          # dc dispatcher + dcup/dcdown/dcps/dcx/dcq/dclt
├── compose-modern.sh        # dcw (watch), dcrun (one-shot), profile/env-file helpers
├── swarm.sh                 # dss namespace (deploy/rm/svc/ps/logs/scale/nodes)
├── help.sh                  # dhelp / dchelp / dsshelp
├── completion-bash.sh
├── completion-zsh.sh
├── extra/
│   ├── README.md            # how to opt in
│   └── git-properties.sh    # dcpr (NOT loaded by default)
└── docker-color_aliases.sh  # loader (sources all *.sh except extra/)
```

Rationale:
- Splitting `compose-core` from `compose-modern` keeps the SDD phase boundaries clean — phase 2 only touches the modern file.
- `swarm.sh` is isolated; users who don't run swarm pay zero cost and can comment out the source line.
- `extra/` is opt-in. The loader never touches it. README documents how to add `source ~/.marckv.dots/docker-aliases/extra/git-properties.sh` to bashrc.

## 10. Phasing (post-PRD, via SDD)

Each step is a separate `/sdd-new` change. Phases are ordered so each one is reviewable in isolation and rollback of any single phase doesn't break the others.

1. **`docker-aliases-restructure`** — file split per §9 (`compose.sh` → `compose-core.sh` + `compose-modern.sh`, new `swarm.sh` placeholder, move `dcpr` → `extra/git-properties.sh`). Pure structural refactor, no behavior change. Lowest risk.
2. **`docker-aliases-triage`** — drop & merge. Remove `dc ul`, `dc s1`, `d top`, `d kill`, `dcleanup`, prune variants; merge `l100/l300/l500` → `dclt -n`. Rename `ds` → `dstats` to free the swarm prefix. **Break-clean** — no deprecated wrappers.
3. **`docker-aliases-ux`** — preview/icon redesign + confirmation rework + Nerd Font detection in `_init.sh`. Affects every preview-producing function. Bash + zsh fallback verified.
4. **`docker-aliases-modern-compose`** — add `dcw` (watch), `dcrun` (one-shot), `-P` (profile), `-e` (env-file). Lives in `compose-modern.sh`. Completion updated.
5. **`docker-aliases-swarm`** — fill in `swarm.sh` with the 10 `dss*` commands + completion + `dsshelp`.
6. **`docker-aliases-bake`** — add `dcb --bake` opt-in path.
7. **`docker-aliases-completion-cache`** — completion cache layer in `_init.sh` (5s TTL by default), hook into compose's official completion as fallthrough. Bash + zsh.

---

## Appendix: command count delta

| Surface | Today | Proposed | Delta |
|---|---:|---:|---:|
| `d` subcommands | 30 | 0 (dispatcher dropped) | −30 |
| Flat aliases (docker) | 8 | 6 | −2 |
| `dc` subcommands | 27 | 18 | −9 |
| Flat aliases (compose) | 6 | 7 (+ `dcw`, `dcrun`) | +2 |
| Standalone functions | 10 | 9 (drop `dcleanup`) | −1 |
| Swarm aliases | 0 | 10 | +10 |
| **Total** | **81** | **50** | **−31** |
