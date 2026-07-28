# `dcd` — jump to a container's compose project directory

Compose stamps every container it creates with labels naming its project, its
service, its working directory and its compose files. `dcd` reads those and
takes you there.

- **Source:** [`commands/dcd.sh`](../commands/dcd.sh)
- **Completion:** [`completions/dcd.bash`](../completions/dcd.bash) · [`completions/dcd.zsh`](../completions/dcd.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dcd [flags] <pattern>
```

Unlike every other command here, `dcd` does **not** care what directory you are
in. It searches every container on the host — that is the whole point.

## Flags

| Flag | Meaning |
|---|---|
| `-p` | Print the path and do not cd — for scripting |
| `-i` | Show the details and do not cd |
| `-h`, `--help` | Show the built-in help |

## Examples

```bash
dcd redmine               # jump to the redmine project
dcd '^redmine$'           # exactly that container
dcd -i redmine            # look without moving
cd "$(dcd -p redmine)"    # compose with other commands
code "$(dcd -p redmine)"  # open the project in an editor
```

## What it shows

```
   redmine-docker  ·  3/3 running
   redmine backup postgres
   docker-compose.yml
   docker-compose.override.yml
   /home/villcabo/DockerProjects/redmine-docker
──────────────────────────────────────────────────────────────────────────
```

The project, how much of it is up, its services, its compose files, and where
it lives. The count is green only when the whole project is running — a
half-running project is worth noticing on the way in.

Compose files come from the labels as absolute paths and are shown relative to
the project directory, which is where they almost always live.

## Ambiguity is about the destination, not the container

`dcd redmine` matches `redmine`, `redmine-postgres` and `redmine-db-backup` —
three containers, one project, one directory. That is not ambiguous, and `dcd`
just goes:

```
$ dcd redmine
   redmine-docker  ·  3/3 running
```

A pattern that spans two *projects* genuinely has two answers, so it stops:

```
$ dcd keycloak
  dcd: 'keycloak' spans 2 projects
  gpgwbackofficejhiangular  /home/villcabo/SintesisProjects/.../src/main/docker
  kctheme-compose           /home/villcabo/DockerProjects/keycloak-docker
  → narrow the pattern
```

## Stopped containers count

`docker inspect` reads stopped containers perfectly well, and a project you want
to jump to is quite often one that is currently down. Searching only running
containers would fail exactly when you need it.

## Environment variables are never shown

`docker inspect` will hand over `.Config.Env` without complaint, and in a real
project that means database passwords and API tokens. Printing them would put
those secrets in your scrollback — and in any recording, screen share or pasted
snippet that follows.

There is no flag to enable it. If you need them, `docker inspect` is right
there and the decision is yours to make deliberately.

## Errors

| Code | When |
|---|---|
| `0` | Jumped, printed, or showed the details |
| `1` | No match, two projects, no pattern, bad flag, not a compose container, directory gone |

```
  dcd: 'zzz' ...
  dcd: no match was created by docker compose: plain-box
  no com.docker.compose labels — nowhere to jump to
```

## Notes

**Why this must be a shell function.** `cd` only affects the shell that runs
it. A script runs in a child process, changes its own directory, and exits —
leaving you exactly where you were. That is also why `-p` exists: inside
`$( )` the `cd` cannot reach you, so the path is printed instead.

**One inspect call.** All matched containers are inspected in a single
`docker inspect a b c` rather than one call each.

## Related

- [`dcup`](dcup.md) · [`dclt`](dclt.md) · [`dcdown`](dcdown.md) · [`dcx`](dcx.md)
- [README](../README.md) — layout and design rules
