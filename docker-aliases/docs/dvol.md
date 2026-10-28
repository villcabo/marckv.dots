# `dvol` — volumes, who holds them, and what a cleanup frees

Lists every volume with the project it belongs to, the container holding it,
and whether a cleanup would actually remove it. A third of the volumes on a
working host are anonymous — 64 hex characters that say nothing — and this is
how you find out what they are.

- **Source:** [`commands/dvol.sh`](../commands/dvol.sh)
- **Completion:** [`completions/dvol.bash`](../completions/dvol.bash) · [`completions/dvol.zsh`](../completions/dvol.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dvol [-u] [-s] [pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-u` | Only the unused volumes — exactly what a prune would remove |
| `-s` | Add each volume's size, and total what a cleanup frees. **Costs ~4 s** |
| `-h`, `--help` | Show the built-in help |

Short flags combine: `dvol -us`.

## The USE column

| Value | Means | A prune |
|---|---|---|
| `N running` | mounted by a running container | keeps it |
| `stopped` | only **stopped** containers mount it | **keeps it** |
| `unused` | nothing mounts it | removes it |

The same rule as [`dnet`](dnet.md), and for the same reason: a stopped
container still holds its volume, so a prune leaves that data alone. Counting
"not mounted by anything running" as unused would promise space a cleanup
never frees.

`unused` here is checked against docker's own definition — on a real host it
matched `docker volume ls -f dangling=true` volume for volume (22 of 22).

## Output

```
  [docker] docker volumes  ·  7 of 56  ·  filter: nginx-base-full
  CREATED     USE        PROJECT          USED BY                   DRIVER  NAME
  2026-10-20  1 running  nginx-base-full  nginx-base-full-vector-1  local   nginx-base-full_geoip
  2026-10-20  2 running  nginx-base-full  nginx-base-full-nginx-1   local   nginx-base-full_nginx_logs
  2026-10-20  unused     nginx-base-full  —                         local   nginx-base-full_trivy_cache
  21 running · 13 held by stopped containers · 22 unused — add -s for how much they free
```

- **`USED BY`** names the container holding the volume — and for a `stopped`
  one it names the stopped container, which is what you would remove first.
- **Anonymous volumes** show their first 12 characters and an ellipsis, and say
  `anonymous` in the `PROJECT` column. The cut is visible on purpose; named
  volumes are never cut.
- **`CREATED`** is the day only. The day is what tells a leftover apart.

## Sizes: `-s`

```
$ dvol -us
  CREATED     USE     PROJECT          USED BY  SIZE     NAME
  2026-10-20  unused  nginx-base-full  —        1.643GB  nginx-base-full_trivy_cache
  2026-10-21  unused  —                —        1.64GB   trivy_cache_lordaeron
  21 running · 13 held by stopped containers · 22 unused, 8.4GB reclaimable
```

With `-s` the `DRIVER` column becomes `SIZE`, and the tally totals what the
unused volumes take. That total is checked against docker: on the host above,
`docker system df` reported **8.387 GB** reclaimable and `dvol` reported
**8.4 GB**. Only `unused` volumes count — the data of a stopped container is
not reclaimable until that container is gone.

Sizes come from `docker system df -v`, which takes ~3.5 s on its own, so they
are opt-in. Without `-s`, nothing waits on that call.

## Examples

```bash
dvol                    # every volume
dvol -us                # what a cleanup removes, and how much it frees
dvol postgres           # by name, project or holding container
dvol -s keycloak        # how big that project's data is
dvol anonymous          # just the anonymous ones
```

## Exit codes

| Code | When |
|---|---|
| 0 | Something was shown, or no filter was given |
| 1 | A pattern or `-u` matched nothing, an unknown flag, or no daemon |

## Performance

Four docker calls without `-s`, whatever the number of volumes: `volume ls`,
one `volume inspect` for all of them, `ps -a`, and one `inspect` of every
container for its mounts. `-s` adds `system df -v`. Nothing runs per row.

## Notes

- **No preview, no confirmation.** It only reads.
- Who mounts a volume comes from `docker inspect`, not from
  `docker ps --format {{.Mounts}}` — ps truncates names to fourteen characters
  with an ellipsis, so nothing would match and every volume would look unused.
- docker has two families of `--format`: `ps`, `volume ls` and `system df` turn
  `\t` into a tab *before* parsing the template, `inspect` does not. Each call
  here uses the form its family accepts; mixing them breaks silently.

## Related

- [`dnet`](dnet.md) — the same question for networks
- [`dprune`](dprune.md) — remove the unused ones, with an inventory first
- [`di`](di.md) — the same question for images
