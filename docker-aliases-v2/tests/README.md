# docker-aliases v2 — tests

Proves the aliases behave identically across 7 distros and 2 shells. That
matrix is the whole point: the bugs found so far were never logic bugs, they
were bash-vs-zsh bugs.

## Quick start

```bash
cd docker-aliases-v2/tests

./e2e.sh                 # run on this machine, bash + zsh
./e2e.sh bash            # one shell only

docker compose build     # build the 7 distro images (once)
docker compose up -d     # start them
docker compose exec ubuntu24 bash    # poke around by hand
docker compose exec ubuntu24 zsh     # same box, other shell
docker compose down      # stop them
```

Inside a container the repo is mounted at `/repo`, so:

```bash
source /repo/docker-aliases-v2/init.sh
cd /repo/docker-aliases-v2/tests/fixtures/profiles
dcup -P dev,debug
```

## Run the suite everywhere

```bash
for d in debian11 debian12 debian13 ubuntu20 ubuntu22 ubuntu24 ubuntu26; do
    echo "=== $d ==="
    docker compose exec -T "$d" /repo/docker-aliases-v2/tests/e2e.sh
done
```

## The image matrix

| Service | Base | Ships |
|---|---|---|
| `debian11` | `debian:11` | bash, zsh, docker CLI, compose plugin |
| `debian12` | `debian:12` | ″ |
| `debian13` | `debian:13` | ″ |
| `ubuntu20` | `ubuntu:20.04` | ″ |
| `ubuntu22` | `ubuntu:22.04` | ″ |
| `ubuntu24` | `ubuntu:24.04` | ″ |
| `ubuntu26` | `ubuntu:26.04` | ″ |

**One image per distro, with both shells.** Two images per distro would double
the build, the push and the maintenance to test the very same code — you can
already reach either shell in one container with `bash -c` / `zsh -c`.

**Everything is pinned** (`DOCKER_VERSION`, `COMPOSE_VERSION` build args). No
`latest`, and no GitHub API call — that endpoint rate-limits at 60 requests an
hour unauthenticated, which shows up later as random build failures nobody can
reproduce.

**Images persist.** `docker compose down` removes containers, not images. You
build once; every later run reuses them instantly. Only `--no-cache` or
`down --rmi all` forces a real rebuild.

## Publishing to a registry (optional)

Only worth it for a second machine or CI — on a single box the local images
already do the job. The compose file is ready either way:

```bash
export DA_TEST_NS=<your-dockerhub-user>
docker compose build
docker login                       # interactive — run it yourself
docker compose push
```

Without `DA_TEST_NS` the images tag as `local/docker-aliases-test:<distro>` and
stay on this machine. **Docker Hub repositories are public by default.**

## Fixtures

| Fixture | Covers |
|---|---|
| `basic/` | Three plain services. The default case |
| `profiles/` | `-P`: one always-on service, the rest gated behind `dev` / `debug` / `full` |
| `envfile/` | `-e`: every value interpolated, so the wrong env file is visible |
| `multifile/` | Repeated `-f`: base + override, including an override-only service |
| `detect-env/` | `DOCKER_COMPOSE_FILE=` inside `.env` pointing at `custom.yml` |
| `spaces/` | A compose file literally named `my stack.yml` |
| `volumes/` | Two named volumes — what `dcdown -v` destroys |
| `multimatch/` | `api` and `api-worker` share a prefix — what `dcx` must refuse to guess |

## How the suite stays safe

`docker` is shimmed onto `PATH` before every run. The shim passes read-only
queries through to the real binary and captures everything else as
`ARGV: [...]` instead of running it:

- `config` parses YAML and needs no daemon, so it answers for real.
- `ps` does need one. There is none here, so it fails — which is exactly the
  "cannot reach the daemon" path `dcdown` has to handle.

So the suite asserts against the **exact argv** `dcup` would hand to docker,
while being physically unable to start, stop or delete a container. That is
also why `compose.yml` mounts **no docker socket**: a socket would let a test
inside a container act on the host's real containers.

## What is covered

296 checks per shell, per distro.

`dcx`:

- Shell probe: `sh` fallback **and** the bash branch, both driven by the shim
- An explicit command skips the probe
- `dcx api ls -la` keeps `-la` for `ls` — the parse stops at the pattern
- An ambiguous pattern lists the matches and exits 1 instead of picking one
- `--no-tty` added when there is no terminal; `-u` / `-w` mapping
- Completion switches from services to commands once the pattern is given

`dcdown`:

- `-v` names every volume it would delete, read from `config --volumes`
- `-v` demands the **project name** — `yes` and a wrong name are both rejected
- Without `-v`, `yes` is enough (and a bare `y` still is not)
- `-O` / `-vO` clustering, regex patterns, errors listing what was available
- Always states whether the service list is *running* or *declared* — asserted
  without assuming a daemon, since the suite runs both on a workstation that
  has one and in containers that do not

`dclt`:

- Patterns treated as regex: plain word, alternation, anchored
- Overlapping patterns never duplicate a service
- Line count via bare number, `-n N`, and `-n all`
- `--follow` by default, dropped by `-o`; `-t`, `-s` mapping
- **stdout stays pipe-clean while the preview goes to stderr**
- Never prompts — verified by running it with no stdin at all
- Errors list the services that *were* available

`dcup`:

- `--help` output, including that no `-y` escape is advertised
- Preview: action, files, resolved services, flags, and the command line
- Flag → argv mapping for `-r -p -b -l`, and `-rpl` clustering
- `--env-file` and `--profile` emitted **before** `up` (v1 emitted `--env-file`
  after `up`, where docker rejects it — `-e` never worked in v1)
- Repeated `-f`, comma-split and repeated `-P`
- A filename containing a space surviving as one argv element
- Compose file detection through `.env`
- Exit codes: unknown flag, missing value, missing file, declining → `1`
- Confirmation: `yes`/`YES`/`Yes` accepted; `y`, `Y`, `n`, Enter rejected
- `DOCKER_ALIASES_AUTO_YES` bypass
- Completion for both shells

## What is NOT covered

**Real `docker compose up`.** By design — the shim blocks it. Actually starting
containers does not vary by distro or shell, so the matrix would add risk
without adding signal.

**Interactive TTY behavior.** The suite always runs without a terminal, so it
can assert that `dcx` adds `--no-tty` when there is none — but that a real
terminal gets a real TTY stays a manual check.

**Interactive zsh TAB.** bash completion is tested for real: the suite sets
`COMP_WORDS` / `COMP_CWORD` and reads `COMPREPLY`, exactly as bash does.

zsh cannot be tested that way — `compadd` and `_files` only exist inside a live
completion — so the suite stubs them and drives `_dcup_complete_zsh` directly.
That covers the branching and the data it feeds on, which is where the
portability bugs have actually been. It does **not** cover compsys wiring.
Pressing TAB in a real zsh is still a manual check.
