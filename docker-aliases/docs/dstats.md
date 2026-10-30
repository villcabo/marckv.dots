# `dstats` — resource use, against each container's own limits

`docker stats` shows percentages that do not mean what they look like.
`dstats` shows every number against the container's **own limit**, in the same
unit, so a container about to be throttled or killed looks like one.

- **Source:** [`commands/dstats.sh`](../commands/dstats.sh) (also the shared core of [`dcstats`](dcstats.md))
- **Completion:** [`completions/dstats.bash`](../completions/dstats.bash) · [`completions/dstats.zsh`](../completions/dstats.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dstats [-w] [pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-w` | Watch: redraw until Ctrl-C (every ~2 s — docker's pace) |
| `-h`, `--help` | Show the built-in help |

## What `docker stats` gets wrong, and what this shows instead

**MEM % divides by the host's RAM when there is no limit.** A container with no
memory ceiling shows `0.14%` and reads as calm. It is not calm; it is
unbounded. `dstats` shows `384KiB / ∞`, in yellow — never a green percentage.

**CPU % is relative to one core.** 100% is a full core, so a container limited
to `--cpus 0.5` tops out at **50%**. Measured: a busy loop under a half-core
limit shows `50.71%` — pinned against its ceiling, being throttled — and
nothing in docker's output says so. `dstats` shows `50.7% / 50%`, in red.

```
  docker stats  ·  33 of 33
     CPU            MEM           PIDS       NET I/O           DISK I/O           NAME
  52.33% / 50%   576KiB /  64MiB     2 / 50   16.4kB /   126B        0B /     0B  dxprobe-lim
   1.28%         707MiB /   2GiB   117         1.9MB /   126B     810MB /  2.2GB  crossborder-kafka
   0.10% / 50%   179MiB / 256MiB    18         183kB /  5.1MB    69.9MB / 24.0MB  nginx-api-ws-vector-1
   0.00%        41.9MiB /      ∞     7        20.2MB / 40.7MB    49.0MB / 60.8MB  nginx-api-ws-echo-integrado-1
  35 shown use 2.7GiB of memory (host: 30.1GiB) · CPU 162.72% of 1400% (14 cores)
  [!] 11 with no memory limit — nothing stops one of them from taking the host's RAM
```

| Column | Shows | Colour |
|---|---|---|
| `CPU` | usage, and ` / ceiling` when `--cpus` (or a CPU quota) is set | of the ceiling: red ≥ 90%, yellow ≥ 70%. No limit: yellow past one whole core |
| `MEM` | used / limit, or `/ ∞` when there is none | of the limit: red ≥ 90%, yellow ≥ 70%. `∞`: yellow |
| `PIDS` | processes, and ` / limit` when `--pids-limit` is set | of the limit, same thresholds |
| `NET I/O`, `DISK I/O` | in / out — read / write — since the container started | dim: a total is not a pressure |

**Every figure lines up.** docker prints memory with whatever precision fits
(`33.1MiB`, `30.07MiB`, `8.184MiB`), so `dstats` re-formats every number to one
precision — memory in binary units, one decimal, none from 100 up; a limit
without a decimal when it is round — and right-aligns each half of every
`used / limit` pair against the widest one in its column. The ` / ` sits in the
same place on every row, and each header ends where the figures under it end. Widths are measured by what the terminal shows, not by
bytes, so `∞` does not throw a row off under a C locale.

**Colour means "look here".** An ordinary figure is printed plain; only what is
near a limit, past a core, or unbounded is coloured. Painting every value made
the one that mattered impossible to spot.

**Rows near a limit come first**, then by memory used. Memory is what gets a
container killed; a single CPU sample is too spiky to rank by.

**The footer** sums memory against the host, CPU against the host's cores
(from `docker info`, not `nproc` — under `DOCKER_HOST` the local core count is
the wrong machine's), and counts the containers with no memory limit.

## Examples

```bash
dstats              # every running container
dstats kafka        # only names matching 'kafka'
dstats -w           # keep watching
```

## Performance

One `docker stats --no-stream`, one `inspect` of the same containers, one
`docker info`. Measured with 33 containers: ~2.1–2.4 s, against ~2.0–2.1 s
for bare `docker stats --no-stream`.

That ~2 s is **fixed**: the daemon waits a second collection tick to compute
the CPU delta, and the CLI has no way to skip it. Filtering by name does not
make it faster, only shorter. The same cost sets the pace of `-w`.

## Notes

- **No preview, no confirmation.** It only reads.
- `-w` clears and redraws the screen, as `watch` does — moving the cursor up
  N lines would leave debris whenever a row wraps in a narrow terminal.
- The footer goes to stderr, so `dstats | grep x` gets only the table.

## Related

- [`dcstats`](dcstats.md) — the same table for the current compose project, by service
- [`devents`](devents.md) — whether one of them was killed, and why
