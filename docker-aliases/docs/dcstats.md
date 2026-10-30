# `dcstats` — resource use of this compose project, by service

[`dstats`](dstats.md)' table, narrowed to the compose project you are standing
in and labelled by **service** — the name every `dc` command speaks.

- **Source:** [`commands/dcstats.sh`](../commands/dcstats.sh), on the core in [`commands/dstats.sh`](../commands/dstats.sh)
- **Completion:** [`completions/dcstats.bash`](../completions/dcstats.bash) · [`completions/dcstats.zsh`](../completions/dcstats.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcstats [-f file] [-w] [service-pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-f file` | Compose file (repeatable). Default: resolved as docker does |
| `-w` | Watch: redraw until Ctrl-C (every ~2 s — docker's pace) |
| `-h`, `--help` | Show the built-in help |

## Output

```
  compose stats · dxprobe-rs  ·  3 of 3
    CPU     MEM      PIDS  NET I/O         DISK I/O       SERVICE
  0.00%  388KiB / ∞     1    7.0kB / 126B        0B / 0B  worker #2
  0.00%  384KiB / ∞     1   39.6kB / 126B        0B / 0B  web
  0.00%  384KiB / ∞     1   41.4kB / 126B        0B / 0B  worker
  [!] 3 with no memory limit — nothing stops one of them from taking the host's RAM
```

Every column reads as in [`dstats`](dstats.md#what-docker-stats-gets-wrong-and-what-this-shows-instead):
CPU and memory against their own limits, `∞` where there is none.

A replica past the first gets its number (`worker #2`). Two rows both called
`worker` that cannot be told apart would be worse than one.

## Why not `docker compose stats`

It exists, and its template has no `{{.Service}}` — measured: `can't evaluate
field Service in type *container.statsContext`. It prints container names, and
it has the same percentages problem as `docker stats`. So `dcstats` is
`dstats`' core, filtered by the project's compose label.

## Examples

```bash
dcstats             # every running service of the project
dcstats api         # services matching 'api'
dcstats -w          # keep watching
```

## Performance

Same calls and the same fixed ~2 s as `dstats`, plus resolving the project
name from the compose file.

## Related

- [`dstats`](dstats.md) — every container on the host
- [`dcps`](dps.md) — the project's containers and their state
