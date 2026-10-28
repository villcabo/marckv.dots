# `dprune` — delete what docker no longer uses, after showing exactly what

`docker system prune` asks "Are you sure?" over a paragraph of categories. It
never says **which** containers, networks or images — and its categories hide a
cascade that deletes more than they suggest. `dprune` names every item it will
delete, says **why** each one is on the list, says what it keeps, and then
deletes exactly that list and nothing else.

- **Source:** [`commands/dprune.sh`](../commands/dprune.sh)
- **Completion:** [`completions/dprune.bash`](../completions/dprune.bash) · [`completions/dprune.zsh`](../completions/dprune.zsh) — flags only; it takes no names
- **Shells:** bash and zsh

---

## Usage

```
dprune [-a] [-v] [-n]
```

## Flags

| Flag | Meaning |
|---|---|
| `-a` | Also every tagged image no remaining container uses, and the build cache |
| `-v` | Also every volume no remaining container uses — **this is data** |
| `-n` | Dry run: the full lists on stdout, nothing deleted, nothing asked |
| `-h`, `--help` | Show the built-in help |

There is no `-y`. `DOCKER_ALIASES_AUTO_YES=1` exists for tests and CI only.

## What goes

| | Deleted |
|---|---|
| always | stopped containers (exited, created, dead), the networks they leave unused, dangling images |
| `-a` | + tagged images no remaining container uses, + the build cache |
| `-v` | + volumes no remaining container uses |

Running containers — and every network, image and volume they use — are never
touched. Neither are `bridge`, `host`, `none`, swarm-scope networks,
`docker_gwbridge` or `ingress`.

## The cascade

Removing a stopped container frees whatever it was holding: its networks, its
image, its volumes. `docker system prune` removes containers **first**, so its
later steps take all of that too. Measured on a real host: 23 of 39 networks
had nothing running on them, and all 23 were held by stopped containers. A
preview that asked "which networks are unused right now?" would have said
none — and the prune would have deleted 23.

So every network, image and volume in the preview says which it is:

```
  NETWORKS  24
    cbtest-auth      bridge  freed — its stopped containers go first
    dxprobe-orphan   bridge  unused
```

`freed` is the cascade, in yellow — the part nobody expects. `unused` was
already unused before anything ran.

## The preview

```
  prune  ·  SCSSAADES24  ·  these are DELETED, and cannot be undone

  STOPPED CONTAINERS  160  their filesystems and logs go with them
    nginx-api-ws-log-trim-1  Exited (137) 57 minutes ago  alpine:3.24.2  nginx-api-ws
    kc-theme-test            Exited (143) 5 days ago      quay.io/keycloak/keycloak:26.8.1
    … and 150 more — every one with dprune -n

  NETWORKS  24
    cbtest-auth              bridge  freed — its stopped containers go first
    dxprobe-orphan           bridge  unused
    … and 14 more — every one with dprune -n

  DANGLING IMAGES  42  up to 9.1GB — images share layers, docker may free less
    …

  KEPT
    35 running container(s), and every network, image and volume they use
    volumes: not touched — 35 unused would go with -v
    tagged images: 205 unused, kept — they go with -a
    build cache: 71.33GB, kept — it goes with -a

  runs, in this order — each item by name, never with -f:
    docker rm dxprobe-loop dxprobe-oom dxprobe-ev … +157 more
    docker network rm cbtest-auth cbtest-mon cbtest-pg … +21 more
    docker rmi 3f2a9c1b7d4e … +41 more
  ──────────────────────────────────────────────────────────────────
  [!] This deletes 160 container(s), 24 network(s), 42 image(s) on SCSSAADES24, permanently. Type the host name to confirm:
  [SCSSAADES24]:
```

- **Lists are capped at ten items** per section, with the full count in the
  heading and `dprune -n` for every one. A 160-line preview is not read; a
  capped one with its total in plain sight is. **Volumes are never capped**:
  they hold data, so each one is shown in red with its project and size.
- **KEPT is part of the preview.** Saying what stays is what lets you read the
  list above it as complete.
- **Image sizes are an upper bound**: images share layers, and docker frees
  only the layers no other image uses. Two tags of one image count once.

## The confirmation is the host's name

Everything `dprune` does is irreversible, and `yes` is the answer to every
other prompt — type it often enough and you stop reading the question. So you
type the docker host's name instead. It comes from `docker info`, which means
that with `DOCKER_HOST` pointing at another machine, the name you have to type
is **that** machine's. The prompt cannot be answered without noticing where it
is about to delete.

## What it shows is what it deletes

The preview is not a description of a prune that runs afterwards. Every item
is deleted by its own ID or reference — `docker rm <ids>`, `docker network rm
<ids>`, `docker volume rm <names>`, `docker rmi <refs>` — in cascade order,
**never with `-f`**. A prune command would re-evaluate at run time and could
take something that changed after you read the list; deleting by name cannot.
And without `-f`, anything that started using an item between the preview and
your answer makes docker **refuse** that one item instead of deleting it:

```
  containers   160 deleted
  networks     24 deleted
  images       41 deleted, 1 refused
      Error response from daemon: conflict: unable to remove repository reference "busy/img:1" …
```

The build cache is the one exception — it has no IDs to name — and it is only
touched with `-a`, which is exactly the case `docker builder du` reports
precisely. A default `builder prune` frees a share of it that nobody can
preview, so `dprune` does not offer that.

## Measured traps it avoids

- **Plain `docker images` hides dangling images** on the containerd image
  store, docker 29's default: 42 of them on the measured host, visible only
  with `-a` or `--filter dangling=true` (`di` learned this first). `-a` is wrong
  too: on the classic store it adds intermediate layers that `image prune`
  never removes. The dangling filter is the exact set, on either store.
- **A dangling image can still be running.** Re-tag an image and the old one
  becomes dangling while its container keeps running. `dprune` keeps it.
- **Tagged images are deleted by reference, not by ID**: an ID with two tags
  makes `docker rmi <id>` refuse without `-f`.

## Examples

```bash
dprune -n              # everything it would delete, uncapped, nothing deleted
dprune -n | less       # the same, paged
dprune                 # stopped containers, the networks they free, dangling images
dprune -a              # plus unused tagged images and the build cache
dprune -av             # everything unused, volumes included
```

## Performance

`docker info`, `ps -a`, one `inspect` of every container, `network ls`, two
`images`, `volume ls` and `builder du`: about 2 s on a host with 196
containers. `-v` adds `docker system df -v` for the volume sizes (~3.5 s) —
paid only when the sizes of what is about to be destroyed are the thing you
need to see.

## Exit codes

| Code | When |
|---|---|
| 0 | It ran, nothing was left to prune, or it was a dry run |
| 1 | The confirmation was not the host's name, an unknown flag or argument, or no daemon |

## Related

- [`dvol`](dvol.md) — which volumes are used, stopped-only or unused, before you add `-v`
- [`dnet`](dnet.md) — the same for networks
- [`di`](di.md) — images, and which ones a container uses
- [`devents`](devents.md) — what happened to a container before you delete it
