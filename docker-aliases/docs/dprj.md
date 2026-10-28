# `dprj` — compose projects on this host

Lists the compose projects living on this host: how many of their containers
are up, which compose files they were started from, and where they live. The
name it shows is what [`dcd`](dcd.md) takes — `dprj` finds a project, `dcd`
takes you there.

- **Source:** [`commands/dprj.sh`](../commands/dprj.sh)
- **Completion:** [`completions/dprj.bash`](../completions/dprj.bash) · [`completions/dprj.zsh`](../completions/dprj.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dprj [-a] [pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-a` | Include projects with nothing running |
| `-h`, `--help` | Show the built-in help |

## Output

```
  [docker] compose projects  ·  7 of 15  ·  filter: running only
  NAME                  UP   STATE    SERVICES  FILES            DIRECTORY
  nginx-api-ws          7/9  partial  9         compose.yaml +1  ~/SintesisProjects/nginx-api-ws
  bastion-lab           9/9  running  9         compose.yaml     ~/PersonalProjects/bastion-zero-trust/laboratorio
  crossborder-infra     1/3  partial  3         compose.yaml     /tmp/claude-…/scratchpad/cb-infra-test
  15 projects · 27 containers up · 8 stopped, see dprj -a
  [!] 5 run from /tmp — tmpfs, gone after a reboot
  go to one with dcd <name>
```

| Column | Means |
|---|---|
| `UP` | running containers of total — counted in containers, so a scaled service counts each replica |
| `STATE` | `running` (all up), `partial` (some), `stopped` (none, only with `-a`) |
| `SERVICES` | distinct services — a service with two replicas is one |
| `FILES` | the first compose file, and `+N` for the others started with it |
| `DIRECTORY` | the project directory, relative to `~` |

**`partial` is the one to look at.** It means part of the project is down, and
on a real host it is usually a container that crashed and nobody noticed.

**`+1` in `FILES`** is almost always a `docker-compose.override.yml`. Seeing it
explains a project that does not behave the way its main file says.

**The directory goes last.** It is the long column, and a last column needs no
padding — so it stays whole instead of pushing every row out of line.

## Projects under `/tmp`

`/tmp` is a tmpfs: it is empty after a reboot. A project living there loses its
compose files on the next boot, and one with a restart policy can leave dockerd
recreating its bind-mount sources as root when it starts. `dprj` counts them
for the whole host — even when a filter hides them — and says so:

```
  [!] 5 run from /tmp — tmpfs, gone after a reboot
```

## Examples

```bash
dprj                    # what is running
dprj -a                 # everything, stopped projects included
dprj nginx              # by project name or directory
dprj -a && dcd nginx    # find it, then go there
```

## How it is built

From the compose **labels** on every container, in one `docker ps -a`. That is
the data `docker compose ls` derives its own answer from — but as plain
tab-separated text. `docker compose ls --format json` is the obvious source, and
it cannot be used: these scripts cannot parse JSON, because `jq` is not on the
servers they run on. Checked against `docker compose ls -a` on a real host: the
same fifteen projects and the same running/total counts.

Containers compose did not create carry no project label and are skipped.

## Exit codes

| Code | When |
|---|---|
| 0 | Something was shown, or no pattern was given |
| 1 | A pattern matched nothing, an unknown flag, or no daemon |

## Performance

One `docker ps -a`, whatever the number of projects. Measured with 180
containers in 15 projects: ~240 ms, against ~130 ms for `docker compose ls`
— the difference is the price of not needing a JSON parser.

## Notes

- **No preview, no confirmation.** It only reads.
- The footer goes to stderr, so `dprj | grep x` gets only the table.

## Related

- [`dcd`](dcd.md) — go to a project's directory by name
- [`dcps`](dps.md) — the containers of the project you are standing in
- [`dps`](dps.md) — every container on the host
