# `dver` — which build is running, host-wide

The question [`dcver`](dcver.md) answers, asked of the whole machine instead of
one compose project. The same pairing `dps`/`dcps` already established:

| | Host | Compose project |
|---|---|---|
| What is running | [`dps`](dps.md) | [`dcps`](dps.md) |
| **What build is running** | **`dver`** | [`dcver`](dcver.md) |

- **Source:** [`commands/dver.sh`](../commands/dver.sh)
- **Completion:** [`completions/dver.bash`](../completions/dver.bash) · [`completions/dver.zsh`](../completions/dver.zsh)

---

## Usage

```
dver [flags] [pattern...]
```

## Flags

| Flag | Meaning |
|---|---|
| `-a` | Also list containers with no `git.properties` |
| `-r` | Raw: print the whole file instead of a table |
| `-h`, `--help` | Show the built-in help |

Patterns are regular expressions matched against **container names**, as in
[`dps`](dps.md) and [`dcd`](dcd.md).

## What it looks like

```
 docker versions · 2 of 20
NAME              PROJECT           VERSION        COMMIT   BRANCH   BUILT
gpgw-backoffice   gpgwbackoffice    1.1.0-d3cabc9  d3cabc9  main     2y   ⚠ dirty
atcqrms-api       gpgw-atcqrms      2.0.1-aabbccd  aabbccd  develop  3d
 18 with no git.properties (postgres, keycloak, traefik…)  -a to show
```

## Containers without a version are hidden

Most of a host is postgres, keycloak, redis and traefik — none of which carries
a `git.properties`. Listing all twenty to surface two turns the answer into a
haystack, so the ones without are left out.

Nothing is hidden quietly:

- The header says **`2 of 20`**, so you can see everything was asked.
- The footer **names** the ones left out, so the omission is checkable.
- `-a` shows them anyway.

This is the opposite of [`dcver`](dcver.md), which lists everything: a compose
project has a handful of services and you usually want to see that a particular
one has no version rather than wonder where it went.

## `PROJECT` earns its column here

Host-wide, containers come from many projects and knowing which is which is
half the point — it is also what [`dcd`](dcd.md) takes you to. Unlike
[`dps`](dps.md) there is no IMAGE column crowding the row, so it fits.

## Everything else works like `dcver`

The search paths, `DOCKER_ALIASES_GIT_PROPS`, the parsing, and the meaning of
**⚠ dirty** — a build made from uncommitted changes, which nobody can rebuild
from the commit it names — are all shared. See [dcver.md](dcver.md).

Containers are queried concurrently: twenty of them cost one round trip, not
twenty.

## Notes

**Only running containers.** `docker exec` needs one. A stopped container cannot
be asked, so it does not appear at all.

## Related

- [`dcver`](dcver.md) — the same, scoped to one compose project
- [`dps`](dps.md) — what is running
- [v2 README](../README.md)
