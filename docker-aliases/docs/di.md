# `di` — list images, and what you could delete

- **Source:** [`commands/di.sh`](../commands/di.sh)
- **Completion:** [`completions/di.bash`](../completions/di.bash) · [`completions/di.zsh`](../completions/di.zsh)

---

## Usage

```
di [flags] [pattern...]
```

## Flags

| Flag | Meaning |
|---|---|
| `-u` | Only images no container is using |
| `-d` | Only dangling images |
| `-t` | Exact creation date instead of how long ago |
| `-s` | Add the reclaimable size to the footer — costs ~300ms, see below |
| `-h`, `--help` | Show the built-in help |

Patterns are regular expressions matched against **`repository:tag`**, so a tag
alone finds an image — `di 18-alpine` works.

## What it looks like

```
 docker images · 47 of 47
REPOSITORY                 TAG       IMAGE ID      CREATED  SIZE    USED
local/docker-aliases-test  ubuntu24  812e61bcaefe  57m      179MB   1
quay.io/keycloak/keycloak  26.6.2    9b0455f766d5  2mo      474MB   1
redmine-mcp-lab            6.1.3     da4eecadf851  28h      907MB   —
<dangling>                 —         7f7b633061f6  19h      179MB   —
 15 dangling · 28 unused
```

With `-s`, the footer also carries how much disk that would give back:

```
 15 dangling · 28 unused · 4.721GB (37%) reclaimable
```

Column order is `docker images`'s own — `REPOSITORY TAG IMAGE ID CREATED SIZE`
— with `USED` added. Muscle memory beats any ordering we could invent.

## It answers "what can I delete?"

The old `di` was `docker images | docker-color-output`: a list. But on a working
machine that list is mostly things you no longer need — here, 15 of 47 images
are dangling and 28 more have no container using them, together holding 4.7GB.

Three additions turn the list into an answer:

**`USED`** — how many containers refer to the image. A `—` means none do. The
count is shown rather than a checkmark because *6 containers on one image* says
something a tick cannot.

**`<dangling>`** instead of `<none>:<none>` — an image that lost its tag to a
rebuild. Docker's own rendering reads like a bug rather than a state.

**The footer** — how many are dangling, how many unused, and how much is
genuinely reclaimable.

## Dangling images are shown, not hidden

This is the opposite call from [`dver`](dver.md), which hides containers with no
version. There, what got hidden was noise. Here it is the answer: dangling
images are half the list *and* the thing you came to find.

Worth knowing: **`docker images` hides them by default.** They only appear under
`-f dangling=true` (or `-a`, which on an older daemon also drags in every
intermediate build layer). `di` runs the explicit dangling query as a second
call, so the count is right on any version. The first version of this command
did not, and cheerfully reported `0 dangling` with fifteen of them on disk.

## The reclaimable figure is not a sum

It comes from `docker system df`. Adding up the sizes of the dangling and
unused images gives **10.32GB** on this machine where the truth is **4.72GB** —
images share layers, so a shared base counts once per image that references it.

A footer that overstates by more than double is worse than no footer, so this
one asks docker rather than doing arithmetic.

**Which is why it is behind `-s`.** Honest costs: `docker system df` walks every
volume and every build cache entry on the host — 209 and 152 of them on this
machine — to answer one question about images, and there is no way to narrow it
down, the command takes no `--type`. Measured at **333ms**, against roughly
130ms for everything else `di` does put together. It was also being called
before the check that decides whether to print anything, so a host with nothing
to reclaim paid for the number twice over: once to compute it, once to throw it
away.

The `dangling` and `unused` counts come free with the listing that is already on
screen, so those stay. The figure that costs ten times the command is one `-s`
away when you actually want it.

The footer also **disappears on a filtered view** (`di nginx`, `di -u`): those
totals describe the machine, and printing them under rows that do not represent
the machine reads as a claim about those rows.

## Related

- [`dps`](dps.md) — what is running
- [`dver`](dver.md) — which build is running
- [README](../README.md)
