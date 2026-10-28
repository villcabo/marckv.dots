# `dnet` — networks, their subnets, and what uses them

Lists every network with its subnet, and says honestly whether anything uses
it. On a host that has run a few compose projects, most networks are leftovers —
but "nothing running on it" is not the same as "nothing uses it", and that
difference is what this command exists to show.

- **Source:** [`commands/dnet.sh`](../commands/dnet.sh)
- **Completion:** [`completions/dnet.bash`](../completions/dnet.bash) · [`completions/dnet.zsh`](../completions/dnet.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dnet [-u] [pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-u` | Only the unused networks — exactly what a prune would remove |
| `-h`, `--help` | Show the built-in help |

Short flags combine: `-uh`.

## The USE column

| Value | Means | A prune |
|---|---|---|
| `N running` | containers are on it now | keeps it |
| `stopped` | only **stopped** containers point at it | **keeps it** |
| `unused` | nothing points at it at all | removes it |
| `built-in` | `bridge`, `host`, `none` | never touches it |

**`stopped` is the one that matters.** A stopped container still references its
network, so `docker network prune` leaves that network alone until the
container is gone. Measured on a real host: **23 of 39 networks had no running
container, and every one of the 23 was held by a stopped one.** A command that
counted "no running container" as unused would have reported 23 leftovers and
pointed at a prune that removes none of them.

So `dnet` asks the second question too — which networks *any* container points
at, running or stopped — and only calls a network `unused` when the answer is
none.

## Output

```
  [docker] docker networks  ·  14 of 41
  SUBNET           GATEWAY       DRIVER            USE        PROJECT        NAME
  172.31.62.0/24   172.31.62.1   bridge, internal  2 running  bastion-lab    bastion-lab_db
  10.100.0.0/24    10.100.0.1    bridge            built-in   —              bridge
  172.29.0.0/16    172.29.0.1    bridge            stopped    —              cbtest-auth
  10.100.6.0/24    10.100.6.1    bridge            unused     —              dxprobe-orphan
  —                —             host              built-in   —              host
  16 running · 22 held by stopped containers · 1 unused — dprune removes them
```

- **`internal`** marks a network with no route out — why a container on it
  cannot reach the internet. It is usually set on purpose.
- **`PROJECT`** is the compose project that created the network, `—` for one
  made by hand.
- **The tally** at the bottom always counts the whole host, never just the
  filtered rows, so a filter cannot make the leftovers look smaller than they
  are. It goes to stderr, so `dnet | grep x` stays clean.

When nothing is unused but some networks are held by stopped containers, the
tally says where to look next:

```
  16 running · 22 held by stopped containers · 0 unused
  the stopped ones go once their containers do — see dps -a
```

## Examples

```bash
dnet                 # every network
dnet -u              # what could actually be cleaned up
dnet 10.100          # which network owns that range
dnet bastion-lab     # by compose project
dnet _backend        # by name
```

## Exit codes

| Code | When |
|---|---|
| 0 | Something was shown, or no filter was given |
| 1 | A pattern or `-u` matched nothing, an unknown flag, or no daemon |

## Performance

Three docker calls whatever the number of networks: `network ls`,
one `network inspect` for all of them, and one `ps -a` for every network any
container points at. Measured with 42 networks and 180 containers:
**335–441 ms**, against ~465 ms for those three calls alone.

## Notes

- **No preview, no confirmation.** It only reads.
- Networks are listed in `docker network ls` order, as `dps` keeps
  `docker ps` order.
- `docker inspect --format` keeps `\t` literal, unlike `docker ps --format`, so
  the template uses `{{"\t"}}` for its separators.

## Related

- [`dip`](dip.md) — which container holds a given address on these networks
- [`dprune`](dprune.md) — remove the unused ones, with an inventory first
- [`dps`](dps.md) — `dps -a` finds the stopped containers holding a network
