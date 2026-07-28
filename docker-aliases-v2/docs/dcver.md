# `dcver` — which build is running in each service

Reads `git.properties` out of running containers and answers the question you
are actually asking: **is this the version I think it is?**

- **Source:** [`commands/dcver.sh`](../commands/dcver.sh)
- **Completion:** [`completions/dcver.bash`](../completions/dcver.bash) · [`completions/dcver.zsh`](../completions/dcver.zsh)
- **Replaces:** v1's `dcpr`

---

## Usage

```
dcver [flags] [pattern...]
```

## Flags

| Flag | Meaning |
|---|---|
| `-r` | Raw: print the whole `git.properties` instead of a table |
| `-f <file>` | Compose file to use. Repeatable |
| `-e <file>` | Env file to use. Repeatable |
| `-P <profile>` | Compose profile. Repeatable, or comma-separated |
| `-h`, `--help` | Show the built-in help |

Patterns are regular expressions matched against service names, as in
[`dclt`](dclt.md).

## What it looks like

```
 compose versions · 2 of 3
SERVICE   VERSION        COMMIT   BRANCH   BUILT
cleanapp  1.1.0-d3cabc9  d3cabc9  main     2y
dirtyapp  2.0.0-aabbccd  aabbccd  develop  3d      ⚠ dirty
nothing   —              —        —        —       no git.properties
```

The count is *how many carried a `git.properties`* out of how many were asked —
a service without one is listed and said so, never quietly dropped.

## What changed from `dcpr`

v1 printed the 40-character commit hash and the **full commit message**, which
on a merge commit is a paragraph. Meanwhile it ignored the three fields that
answer the question fastest:

| Field | Example | v1 |
|---|---|---|
| `app.version` | `1.1.0-d3cabc9` | ignored |
| `git.dirty` | `true` | ignored |
| `git.commit.time` | `2024-04-18T16:56:45` | ignored |
| `git.commit.id.abbrev` | `d3cabc9` | showed all 40 chars instead |

It also passed values through **unescaped**. Java `.properties` escapes colons
on write, so v1 rendered timestamps as `2024-04-18T16\:56\:45-0400`.

And it queried services one after another. `dcver` asks them concurrently, so a
project with eight services costs one round trip rather than eight.

## The dirty flag

`⚠ dirty` means `git.dirty=true`: the artifact was built from a working tree
with uncommitted changes.

That matters more than it looks. **Nobody can rebuild that artifact from the
commit it names** — the commit is a hint about where the build started, not a
description of what it contains. When a deployed service behaves in a way its
source does not explain, this is the first thing worth ruling out.

A clean build carries no flag, so the flag keeps meaning something.

## Where it looks

Seven locations, covering Spring Boot layouts and nginx-served frontends:

```
/app/resources/git.properties
/app/BOOT-INF/classes/git.properties
/app/classes/git.properties
/app/git.properties
/deployments/git.properties
/usr/share/nginx/html/git.properties
/usr/share/nginx/html/assets/git.properties
```

Add your own — searched first, `:`-separated:

```bash
export DOCKER_ALIASES_GIT_PROPS=/opt/app/git.properties:/srv/git.properties
```

`-r` prints which path a file came from, which is the quick way to find out
where your image actually puts it.

## Notes

**Only running containers.** `docker compose exec` needs one, so a stopped
service shows as `no git.properties`. That is a limit of the mechanism, not a
choice.

**No preview, no confirmation.** Read-only, like [`dclt`](dclt.md) and
[`dps`](dps.md) — the table is the output.

## Related

- [`dps` / `dcps`](dps.md) — what is running
- [`dcd`](dcd.md) — jump to the project
- [v2 README](../README.md)
