# docker-aliases smoke tests

Self-contained test suite for the `docker-aliases` module restructure. Verifies all functions, aliases, completions, opt-in behavior, and stub no-ops across bash and zsh on multiple distros.

## What it tests

- **Loader source**: `docker-color_aliases.sh` exits 0 in bash and zsh
- **Functions**: all 12 expected functions are defined (`d`, `dc`, `dcup`, `dq`, `dcq`, `dstatus`, `dcleanup`, `dclt`, `dip`, `_dip_impl`, `_dc_parse_args`, `_dc_resolve_file`)
- **Aliases**: all 14 expected aliases are defined (`dps`, `dps1`, `di`, `dl`, `dlt`, `dpri`, `ds`, `dx`, `dcps`, `dcps1`, `dcl`, `dcdown`, `dcs`, `dcx`)
- **Opt-in (`dcpr`)**: absent after default load; present after `source extra/git-properties.sh`
- **Stubs**: `compose-modern.sh` and `swarm.sh` source cleanly without adding any functions
- **Completions**: `complete -p d` and `complete -p dc` are registered (bash)

## Requirements

- Docker + Docker Compose
- Run from the repo root

## How to run

```bash
cd ~/.marckv.dots
./docker-aliases/tests/smoke.sh
```

## Options

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--keep` | — | off | Skip container teardown on exit (debug mode) |
| `--shell` | `bash`, `zsh`, `both` | `both` | Which shell(s) to test |
| `--distro` | `ubuntu24`, `debian12`, `all` | `all` | Which distro(s) to test |

### Examples

```bash
# Test only bash on ubuntu24
./docker-aliases/tests/smoke.sh --shell bash --distro ubuntu24

# Test only zsh, keep containers running afterwards
./docker-aliases/tests/smoke.sh --shell zsh --keep

# Full sweep
./docker-aliases/tests/smoke.sh
```

## What "passing" looks like

```
  PASS [ubuntu24/bash] loader source → exit 0
  PASS [ubuntu24/bash] function d
  ...
  PASS [debian12/zsh] dcpr absent by default (opt-in only)
  PASS [debian12/zsh] dcpr available after explicit source

=================================================
SMOKE TEST SUMMARY
=================================================
  Total PASS : 62
  Total FAIL : 0
  Elapsed    : 45s

ALL TESTS PASSED
```

Exit code `0` = all tests passed. Any other exit code = at least one failure.

## Interpreting failures

Each failing line shows `FAIL [distro/shell] <what failed>`. Common causes:

| Failure message | Likely cause |
|-----------------|--------------|
| `loader source → exit non-0` | Syntax error in one of the modules |
| `function MISSING: <name>` | Function was removed or not loaded by the loader |
| `alias MISSING: <name>` | Alias definition removed from `docker.sh` or `compose-core.sh` |
| `dcpr should NOT be defined by default` | Loader accidentally sources `extra/` |
| `dcpr NOT available after opt-in source` | `extra/git-properties.sh` broken |
| `compose-modern.sh stub: added functions` | Stub was accidentally populated |
| `complete -p d NOT registered` | Completion file not loaded or function renamed |
