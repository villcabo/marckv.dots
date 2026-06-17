# docker-aliases tests

Two complementary test suites for the `docker-aliases` module:

| Suite | File | What it does |
|-------|------|--------------|
| **Smoke** | `smoke.sh` | Verifies that functions, aliases, and completions **exist** — no live Docker calls |
| **Functional** | `functional.sh` | Actually **executes** commands against real Docker services via the host daemon |

---

## smoke.sh — existence tests

Verifies all functions, aliases, completions, opt-in behavior, and parser internals across bash and zsh on multiple distros. Does not require any running Docker services.

### What it tests

- **Loader source**: `docker-color_aliases.sh` exits 0 in bash and zsh
- **Functions**: all expected functions are defined (post-triage + phases 4–7)
- **Aliases**: all expected aliases are defined; dropped aliases are absent
- **Opt-in (`dcpr`)**: absent after default load; present after `source extra/git-properties.sh`
- **Completions**: all `complete -p` registrations for bash; equivalents for zsh
- **Arg parsing**: `_dc_parse_args -P`, `-e`, `--bake` flag behavior
- **UX helpers**: `_icon`, `_render_preview`, `_confirm_operation`, `_action_color`
- **Cache**: `_cache_set`/`_cache_get` round-trip

### How to run

```bash
cd ~/.marckv.dots
./docker-aliases/tests/smoke.sh
```

### Options

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--keep` | — | off | Skip container teardown on exit (debug mode) |
| `--shell` | `bash`, `zsh`, `both` | `both` | Which shell(s) to test |
| `--distro` | `ubuntu24`, `debian12`, `all` | `all` | Which distro(s) to test |

---

## functional.sh — execution tests

Starts real Docker services inside test containers (using the host docker socket) and actually invokes the aliases. Catches runtime failures that smoke tests cannot detect.

### What it tests

- **Docker commands**: `dps`, `di`, `dstats --once`
- **Compose lifecycle**: `dcup`, `dcps` (all formats), `dcl`, `dcx`, `dcq`, `dclt`, `dstatus`, `dcdown`
- **Modern compose**: `-P` profiles (`dcup -P full`), `-e` env-file flag
- **dcrun**: one-shot ephemeral containers (`dcrun --rm web echo hello`)
- **dprune**: safe system prune
- **Swarm**: `dss`, `dssvc`, `dssnodes` (skipped if host is already in swarm mode)
- **Opt-in dcpr**: absent before, present after `source extra/git-properties.sh`

### What it skips (and why)

- `dcw` (watch): long-running, no clean exit condition without file changes
- `dcb --bake`: requires buildx, environment-dependent
- Swarm deploy lifecycle: skipped if host is already in swarm mode (non-destructive policy)
- `dcrun -P full` in **zsh**: **KNOWN BUG** — `dcrun` uses `read -ra` (bash-only); zsh requires `read -rA`. See `compose-modern.sh:104`.

### Known implementation bugs discovered

1. **`dc up/down/build -f <file>` fails when no compose file in cwd**: `dc()` calls `_get_compose_file()` before parsing subcommand args, so it bails out even when `-f` is given. Workaround: use `DOCKER_COMPOSE_FILE` env var. Location: `compose-core.sh` around line 130.
2. **`dcrun -P <profile>` broken in zsh**: Uses `IFS=',' read -ra _ptmp <<< "$2"` which is bash-specific. Zsh requires `read -rA`. Location: `compose-modern.sh:104`.

### How to run

```bash
cd ~/.marckv.dots

# Fast: ubuntu-24 + bash only
./docker-aliases/tests/functional.sh --distro ubuntu-24 --shell bash

# Full sweep (all distros + both shells, ~2 min)
./docker-aliases/tests/functional.sh
```

### Options

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--keep` | — | off | Skip container/service teardown on exit |
| `--shell` | `bash`, `zsh`, `both` | `both` | Which shell(s) to test |
| `--distro` | `ubuntu-24`, `debian-12`, `all` | `all` | Which distro(s) to test |
| `--quick` | — | off | Run only the most critical ~10 tests |

### What "passing" looks like

```
  PASS [ubuntu24/bash] aliases loaded successfully
  PASS [ubuntu24/bash] dps → exit 0
  ...
  PASS [ubuntu24/zsh] dcrun --rm web echo hello → output contains 'hello'
  SKIP [ubuntu24/zsh] dcrun -P full (zsh) → KNOWN BUG: read -ra not supported in zsh
  SKIP [ubuntu24/zsh] swarm tests — host already in swarm mode (non-destructive skip)

=================================================
FUNCTIONAL TEST SUMMARY
=================================================
  Total PASS : 82
  Total FAIL : 0
  Total SKIP : 6
  Elapsed    : 106s

ALL FUNCTIONAL TESTS PASSED
```

Exit code `0` = all passed (skips don't count as failures).
Exit code `1` = at least one test failed.

---

## Requirements

- Docker + Docker Compose (host daemon reachable from containers)
- Run from the repo root: `cd ~/.marckv.dots`

## Interpreting failures

Each failing line shows `FAIL [distro/shell] <what failed>`. Common causes:

| Failure message | Likely cause |
|-----------------|--------------|
| `loader source → exit non-0` | Syntax error in one of the modules |
| `function MISSING: <name>` | Function was removed or not loaded by the loader |
| `alias MISSING: <name>` | Alias definition removed from `docker.sh` or `compose-core.sh` |
| `dcpr should NOT be defined by default` | Loader accidentally sources `extra/` |
| `dcpr NOT available after opt-in source` | `extra/git-properties.sh` broken |
| `complete -p d NOT registered` | Completion file not loaded or function renamed |
| `dcup → web service NOT running` | dcup failed; check docker daemon access and image pull |
| `dcx web → failed` | Container not running or exec failed |
