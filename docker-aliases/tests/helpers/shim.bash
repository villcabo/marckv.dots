#!/usr/bin/env bash
# docker-aliases tests — the fake docker.
#
# Read-only queries reach the real binary; anything that would mutate state or
# stream forever is captured as `ARGV: [...]` instead. That is what lets the
# suite assert on the exact argv a command would run while being physically
# unable to start, stop or delete a container.
#
# _write_shim <workspace dir> <path to the real docker>
#
# Two things to respect when editing the heredoc below:
#   * It is NOT indented. The delimiter has to sit in column 0, and <<- strips
#     only tabs.
#   * The delimiter is unquoted, so ${WORK} and ${REAL_DOCKER} interpolate as
#     intended — but that also means BACKTICKS RUN. A comment reading
#     `inspect` inside here executed `inspect` every time the shim was written.
#     Keep prose free of backticks and escape any real $ that must survive.
_write_shim() {
    local WORK="$1"
    local REAL_DOCKER="$2"
    mkdir -p "${WORK}/bin"

cat > "${WORK}/bin/docker" <<SHIM
#!/usr/bin/env bash
# Read-only queries reach the real docker; everything that would mutate state or
# stream forever is captured as argv instead.
#
#   config → parses YAML, needs no daemon, so it answers for real.
#   ps     → needs a daemon. There is none here, so it fails, which is exactly
#            the "cannot reach the daemon" path dcdown has to handle.
#
# dcx probes the container for bash before opening a shell. There is no real
# container here, so the answer is driven by DAV2_FAKE_BASH — which lets the
# suite exercise BOTH the bash branch and the sh fallback.
#
# dcver probes each container for git.properties. Answered from an invented
# world so the parsing, the dirty flag and the "not found" row are all
# exercised: cleanapp has one, dirtyapp has a dirty one, nothing has none.
#
# dprune's world. Its calls carry markers nobody else sends (--no-trunc, Scope,
# a project label on volume ls), and this block sits ABOVE dnet's {{.Networks}}
# arm, the generic network/volume ls arms and di's dangling arm — every one of
# which would otherwise answer dprune in its own shape. Each rule has a case:
#   fx-api, fx-db   running                     -> kept, with all they use
#   other-api       exited                      -> deleted; FREES other-proj_default,
#                                                  other-proj_data and image dd3
#   plain-box       created, never started      -> deleted; frees app/worker:1.0
#   orphan-net      nothing on it               -> "unused"
#   docker_gwbridge, ingress, a swarm-scope net -> never touched
#   dd2             dangling but RUN by fx-db   -> kept (a re-tag leaves that)
#   old/tool:2 + old/tool:latest, one image     -> its size counted once
#   busy/img:1      unused, but docker refuses  -> counted as refused
case "\$*" in
    *"ps -a --no-trunc"*)
        printf 'id-fx-api\trunning\tfx-api\tUp 2 hours\tnginx:alpine\tfixture-proj_default\tfixture-proj\n'
        printf 'id-fx-db\trunning\tfx-db\tUp 2 hours\tsha256:dd2\tfixture-proj_default\tfixture-proj\n'
        printf 'id-other-api\texited\tother-api\tExited (137) 2 days ago\tsha256:dd3\tother-proj_default\tother-proj\n'
        printf 'id-plain-box\tcreated\tplain-box\tCreated\tapp/worker:1.0\t\t\n'
        exit 0 ;;
    *"network ls"*"{{.Scope}}"*)
        printf 'n-bridge\tbridge\tbridge\tlocal\nn-host\thost\thost\tlocal\nn-none\tnone\tnull\tlocal\n'
        printf 'n-fx\tfixture-proj_default\tbridge\tlocal\n'
        printf 'n-other\tother-proj_default\tbridge\tlocal\n'
        printf 'n-orphan\torphan-net\tbridge\tlocal\n'
        printf 'n-gw\tdocker_gwbridge\tbridge\tlocal\nn-ing\tingress\toverlay\tswarm\nn-ovl\tapp-overlay\toverlay\tswarm\n'
        exit 0 ;;
    *"volume ls"*"compose.project"*)
        printf 'fixture-proj_pgdata\tfixture-proj\nfixture-proj_cache\tfixture-proj\nother-proj_data\tother-proj\norphan-vol\t\n'
        printf 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2\t\n'
        exit 0 ;;
    *"images --no-trunc --filter dangling=true"*)
        printf 'sha256:dd1\t<none>\t<none>\t120MB\t3 weeks ago\n'
        printf 'sha256:dd2\t<none>\t<none>\t80MB\t2 days ago\n'
        printf 'sha256:dd3\t<none>\t<none>\t300MB\t2 days ago\n'
        exit 0 ;;
    *"images --no-trunc"*)
        printf 'sha256:img-api\tnginx\talpine\t50MB\t3 weeks ago\n'
        printf 'sha256:img-db\tpostgres\t18\t400MB\t2 months ago\n'
        printf 'sha256:img-worker\tapp/worker\t1.0\t200MB\t5 days ago\n'
        printf 'sha256:img-tool\told/tool\t2\t1GB\t1 year ago\n'
        printf 'sha256:img-tool\told/tool\tlatest\t1GB\t1 year ago\n'
        printf 'sha256:img-busy\tbusy/img\t1\t10MB\t1 day ago\n'
        exit 0 ;;
    *"info --format {{.Name}}"*)
        printf 'fixture-host\n'
        exit 0 ;;
esac
if [ "\$1" = "builder" ] && [ "\$2" = "du" ]; then
    printf 'ID\tRECLAIMABLE\tSIZE\tLAST ACCESSED\nabc123*\ttrue\t2.5GB\t2 days ago\n'
    printf 'Shared:\t\t0B\nPrivate:\t2.5GB\nReclaimable:\t2.5GB\nTotal:\t\t2.5GB\n'
    exit 0
fi
# di asks for images and for the reclaimable figure. The invented world mirrors
# the shape that matters: tagged images with and without containers, plus
# dangling ones — which the real docker HIDES from a plain "images" call and
# only returns for "-f dangling=true". (Quotes, not backticks: this comment is
# inside the unquoted heredoc, so backticks here RAN "images" and "-f" as
# commands every time the shim was written — "line 23: images: command not
# found" on every run, two dozen lines below the header that warns about it.)
# dnet: the network world. One network per USE state, because telling them
# apart is what dnet is for:
#   fixture-proj_default   2 running containers
#   other-proj_default     no running container, but other-api points at it   -> stopped
#   orphan-net             nothing points at it, and it is internal           -> unused
#   bridge, host, none     built in
# The ps answer sits up here on purpose: the generic "ps -a" case further down
# would otherwise answer it with container names instead of networks.
case "\$*" in
    *"{{.Networks}}"*)
        printf 'fixture-proj_default\nfixture-proj_default\nother-proj_default\nhost\n'
        exit 0 ;;
esac
# dvol: the volume world, one volume per USE state.
#   fixture-proj_pgdata   mounted by fx-db                   -> 1 running
#   fixture-proj_cache    mounted by fx-api and fx-db         -> 2 running
#   other-proj_data       only other-api, which has EXITED    -> stopped
#   orphan-vol            nothing                             -> unused
#   <64 hex>              nothing, and anonymous              -> unused
if [ "\$1" = "volume" ]; then
    case "\$2" in
        ls)
            printf 'fixture-proj_pgdata\nfixture-proj_cache\nother-proj_data\norphan-vol\na1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2\n'
            exit 0 ;;
        inspect)
            for c in "\$@"; do
                case "\$c" in
                    fixture-proj_pgdata) printf 'fixture-proj_pgdata\tlocal\tfixture-proj\t2026-07-01T10:00:00Z\n' ;;
                    fixture-proj_cache)  printf 'fixture-proj_cache\tlocal\tfixture-proj\t2026-07-02T10:00:00Z\n' ;;
                    other-proj_data)     printf 'other-proj_data\tlocal\tother-proj\t2026-05-20T10:00:00Z\n' ;;
                    orphan-vol)          printf 'orphan-vol\tlocal\t\t2026-03-01T10:00:00Z\n' ;;
                    a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2)  printf 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2\tlocal\t\t2026-04-15T10:00:00Z\n' ;;
                esac
            done
            exit 0 ;;
    esac
fi
if [ "\$1" = "network" ]; then
    case "\$2" in
        ls)
            printf 'bridge\nfixture-proj_default\nhost\nnone\norphan-net\nother-proj_default\n'
            exit 0 ;;
        inspect)
            for c in "\$@"; do
                case "\$c" in
                    bridge)               printf 'bridge\tbridge\t172.17.0.0/16\t172.17.0.1\t0\t\tfalse\n' ;;
                    fixture-proj_default) printf 'fixture-proj_default\tbridge\t172.18.0.0/16\t172.18.0.1\t2\tfixture-proj\tfalse\n' ;;
                    host)                 printf 'host\thost\t\t\t0\t\tfalse\n' ;;
                    none)                 printf 'none\tnull\t\t\t0\t\tfalse\n' ;;
                    orphan-net)           printf 'orphan-net\tbridge\t10.99.0.0/24\t10.99.0.1\t0\t\ttrue\n' ;;
                    other-proj_default)   printf 'other-proj_default\tbridge\t172.180.0.0/16\t172.180.0.1\t0\tother-proj\tfalse\n' ;;
                esac
            done
            exit 0 ;;
    esac
fi
case "\$*" in
    *"dangling=true"*)
        printf '<none>\t<none>\tdd11ee22ff33\t3 days ago\t2026-07-26 08:00:00 -0400 -04\t175MB\t0\n'
        printf '<none>\t<none>\tee22ff33aa44\t3 days ago\t2026-07-26 08:00:00 -0400 -04\t208MB\t0\n'
        exit 0 ;;
    *"{{.Repository}}"*"{{.Containers}}"*)
        printf 'nginx\talpine\taa11bb22cc33\t3 weeks ago\t2026-07-08 10:00:00 -0400 -04\t8.42MB\t2\n'
        printf 'postgres\t18-alpine\tbb22cc33dd44\t2 months ago\t2026-05-20 10:00:00 -0400 -04\t404MB\t0\n'
        printf 'quay.io/example/very-long-image-name\tv1.0.0\tcc33dd44ee55\t5 days ago\t2026-07-24 10:00:00 -0400 -04\t1.37GB\t1\n'
        exit 0 ;;
    *'{{.Repository}}:{{.Tag}}'*)
        printf 'nginx:alpine\npostgres:18-alpine\nquay.io/example/very-long-image-name:v1.0.0\n'
        exit 0 ;;
    *"system df"*"Volumes"*)
        # dvol -s. Checked before the plain "system df" arm below, which
        # answers di and also COUNTS the call — landing there would hand dvol
        # an images figure and inflate di's call counter.
        printf 'fixture-proj_pgdata\t404MB\nfixture-proj_cache\t12.5MB\nother-proj_data\t1.2GB\norphan-vol\t800MB\na1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2\t1.5GB\n'
        exit 0 ;;
    *"system df"*)
        # Recorded, not just answered. The point of -s is that this call does
        # NOT happen without it, and a test can only prove that by watching for
        # the call itself — checking that the figure is absent from the output
        # would pass just as happily if it were made and thrown away.
        printf 'x' >> "${WORK}/system-df-calls"
        printf 'Images\t4.721GB (37%%)\n'
        exit 0 ;;
esac
case "\$*" in
    *"@@PATH@@"*)
        for a in "\$@"; do
            case "\$a" in
                fx-api)
                    printf '@@PATH@@/app/resources/git.properties\n'
                    printf 'app.version=9.9.9-hostwide\ngit.branch=main\n'
                    printf 'git.commit.id.abbrev=ffee001\ngit.dirty=true\n'
                    exit 0 ;;
                fx-db|other-api|plain-box) exit 1 ;;
            esac
        done
        for a in "\$@"; do
            case "\$a" in
                cleanapp)
                    printf '@@PATH@@/app/resources/git.properties\n'
                    printf 'app.version=1.1.0-d3cabc9\ngit.branch=main\n'
                    printf 'git.commit.id.abbrev=d3cabc9\ngit.dirty=false\n'
                    printf 'git.commit.time=2024-04-18T16\\:56\\:45-0400\n'
                    exit 0 ;;
                dirtyapp)
                    printf '@@PATH@@/app/BOOT-INF/classes/git.properties\n'
                    printf 'app.version=2.0.0-aabbccd\ngit.branch=develop\n'
                    printf 'git.commit.id.abbrev=aabbccd\ngit.dirty=true\n'
                    printf 'git.commit.time=2024-04-18T16\\:56\\:45-0400\n'
                    exit 0 ;;
                nothing) exit 1 ;;
            esac
        done
        exit 1 ;;
esac
case "\$*" in
    *"command -v bash"*)
        [ "\${DAV2_FAKE_BASH:-0}" = "1" ] && exit 0 || exit 1 ;;
esac
#
# dcd reaches for the host's containers, which do not exist in here. The shim
# invents a small, fixed world so the grouping logic is testable:
#   fx-api, fx-db  → one project, one directory   (several matches, NOT ambiguous)
#   other-api      → a second project             (a pattern spanning both IS)
#   plain-box      → no compose labels at all
#
# dps and dcps ask for their own formats. Answered with rows that carry the
# messy real-world port strings, so compaction is exercised through the command
# and not only in isolation. Checked BEFORE the plain {{.Names}} case, which
# would otherwise swallow dps's format too.
# inspect is settled FIRST: dcd asks for the compose project LABEL, so a
# format-based match below would hijack it.
if [ "\$1" = "inspect" ]; then
    shift
    # Dispatched on the TEMPLATE before anything else. Every inspect used to
    # land in the dcd branch below and get its five-line answer whatever it
    # asked for, which worked only while dcd was the sole caller. Each command
    # now names a field nobody else asks for, and dcd keeps the fallthrough.
    #
    # dip: one row per container, networks as name=address pairs. The world
    # carries the three traps dip exists to get right:
    #   fx-api  172.18.0.5   vs  fx-db 172.18.0.50   (a substring match lies)
    #   other-api 172.180.0.7                        (172.18 must not catch it)
    #   plain-box on the host network                (docker says "invalid IP")
    case "\$*" in
        *"{{.Id}}"*)
            # dprune: what each container runs and mounts.
            for c in "\$@"; do
                case "\$c" in
                    id-fx-api)    printf 'id-fx-api\tsha256:img-api\t\n' ;;
                    id-fx-db)     printf 'id-fx-db\tsha256:dd2\tfixture-proj_pgdata,fixture-proj_cache,\n' ;;
                    id-other-api) printf 'id-other-api\tsha256:dd3\tother-proj_data,\n' ;;
                    id-plain-box) printf 'id-plain-box\tsha256:img-worker\t\n' ;;
                esac
            done
            exit 0 ;;
        *"HostConfig.NanoCpus"*)
            # dstats/dcstats: limits and compose labels. Typed-mode shapes: an
            # unset PidsLimit and a missing label both print "<no value>".
            for c in "\$@"; do
                case "\$c" in --format|*"{{"*) continue ;; esac
                case "\$c" in
                    fx-api)    printf '/fx-api\t268435456\t500000000\t0\t0\t<no value>\tfixture-proj\tapi\t1\n' ;;
                    fx-db)     printf '/fx-db\t0\t0\t0\t0\t<no value>\tfixture-proj\tdb\t1\n' ;;
                    other-api) printf '/other-api\t268435456\t0\t0\t0\t100\tother-proj\tapi\t1\n' ;;
                    dav2-fixture-basic-api-1)    printf '/dav2-fixture-basic-api-1\t0\t0\t0\t0\t<no value>\tdav2-fixture-basic\tapi\t1\n' ;;
                    dav2-fixture-basic-worker-1) printf '/dav2-fixture-basic-worker-1\t536870912\t0\t0\t0\t<no value>\tdav2-fixture-basic\tworker\t1\n' ;;
                    dav2-fixture-basic-worker-2) printf '/dav2-fixture-basic-worker-2\t536870912\t0\t0\t0\t<no value>\tdav2-fixture-basic\tworker\t2\n' ;;
                esac
            done
            exit 0 ;;
        *"RestartPolicy"*)
            # devents. Times are relative to NOW, so the 24-hour window is
            # exercised for real:
            #   fx-api     running 2h, healthy                      -> "started"
            #   fx-db      exited 137, OOMKilled, 5 min ago         -> "out of memory"
            #   other-api  exited 3, on-failure:3 used up, 10 min   -> "gave up"
            #   plain-box  exited 137, NOT oom, unless-stopped, 3
            #              days ago, and still carrying "unhealthy"
            #              from when it ran — a stopped container
            #              keeps its last health, and must not count
            now=\$(date +%s)
            ts() { date -u -d "@\$1" +%Y-%m-%dT%H:%M:%S.000000000Z; }
            NEVER=0001-01-01T00:00:00Z
            case "\$*" in
            *".Config.Image"*)
                for c in "\$@"; do
                    case "\$c" in --format|*"{{"*) continue ;; esac
                    case "\$c" in
                        fx-api)    printf 'running\t0\tfalse\t0\tunless-stopped\t0\t%s\t%s\t%s\tnginx:alpine\thealthy\t\n' "\$(ts \$((now-7300)))" "\$(ts \$((now-7200)))" "\$NEVER" ;;
                        fx-db)     printf 'exited\t137\ttrue\t0\tno\t0\t%s\t%s\t%s\tpostgres:18-alpine\t\t\n' "\$(ts \$((now-4000)))" "\$(ts \$((now-3900)))" "\$(ts \$((now-300)))" ;;
                        other-api) printf 'exited\t3\tfalse\t3\ton-failure\t3\t%s\t%s\t%s\tquay.io/example/api:1.2.3\t\t\n' "\$(ts \$((now-1000)))" "\$(ts \$((now-620)))" "\$(ts \$((now-600)))" ;;
                        plain-box) printf 'exited\t137\tfalse\t0\tunless-stopped\t0\t%s\t%s\t%s\talpine:latest\tunhealthy\t\n' "\$(ts \$((now-300000)))" "\$(ts \$((now-290000)))" "\$(ts \$((now-259200)))" ;;
                        *) exit 1 ;;
                    esac
                done ;;
            *)
                for c in "\$@"; do
                    case "\$c" in --format|*"{{"*) continue ;; esac
                    case "\$c" in
                        fx-api)    printf '/fx-api\trunning\t0\tfalse\t0\tunless-stopped\t0\thealthy\t%s\t%s\n' "\$(ts \$((now-7200)))" "\$NEVER" ;;
                        fx-db)     printf '/fx-db\texited\t137\ttrue\t0\tno\t0\t\t%s\t%s\n' "\$(ts \$((now-3900)))" "\$(ts \$((now-300)))" ;;
                        other-api) printf '/other-api\texited\t3\tfalse\t3\ton-failure\t3\t\t%s\t%s\n' "\$(ts \$((now-620)))" "\$(ts \$((now-600)))" ;;
                        plain-box) printf '/plain-box\texited\t137\tfalse\t0\tunless-stopped\t0\tunhealthy\t%s\t%s\n' "\$(ts \$((now-290000)))" "\$(ts \$((now-259200)))" ;;
                    esac
                done ;;
            esac
            exit 0 ;;
        *"Config.Healthcheck"*)
            # dhealth. Two templates: the diagnosis asks for the probe command
            # (.Test), the table does not. Typed-mode shapes, as docker prints
            # them: durations "5s", an unset option "0s", Go's default time.
            #   fx-api     healthy
            #   fx-db      unhealthy, 4 in a row, output on TWO lines — the
            #              records must split on \x1e, never on newline
            #   other-api  starting, no probe yet
            #   plain-box  no healthcheck at all
            T='2026-10-25 22:57:28.680780701 -0400 -04'
            case "\$*" in
            *".Test"*)
                for c in "\$@"; do
                    case "\$c" in --format|*"{{"*) continue ;; esac
                    case "\$c" in
                        fx-api)
                            printf 'healthy\t0\tCMD curl -f http://localhost/health\t5s\t3s\t3\t10s\036'
                            printf '%s\t0\tOK\036%s\t0\tOK\036' "\$T" "\$T" ;;
                        fx-db)
                            printf 'unhealthy\t4\tCMD-SHELL pg_isready -U app\t2s\t2s\t2\t0s\036'
                            printf '2026-10-25 22:57:20.1 -0400 -04\t0\taccepting connections\036'
                            printf '%s\t1\tno response\nsecond line of the error\036' "\$T" ;;
                        other-api) printf 'starting\t0\tCMD true\t30s\t0s\t0\t1m0s\036' ;;
                        plain-box) printf 'none\t0\t\036' ;;
                        *) exit 1 ;;
                    esac
                done ;;
            *)
                for c in "\$@"; do
                    case "\$c" in --format|*"{{"*) continue ;; esac
                    case "\$c" in
                        fx-api)    printf '/fx-api\thealthy\t0\t0\t%s\t5s\t3\n' "\$T" ;;
                        fx-db)     printf '/fx-db\tunhealthy\t4\t1\t%s\t2s\t2\n' "\$T" ;;
                        other-api) printf '/other-api\tstarting\t0\t\t\t30s\t0\n' ;;
                        plain-box) printf '/plain-box\tnone\t\t\t\t\n' ;;
                    esac
                done ;;
            esac
            exit 0 ;;
        *".Mounts"*)
            # dvol: each container's state and the volumes it mounts. other-api
            # is EXITED here, which is what makes other-proj_data "stopped".
            for c in "\$@"; do
                case "\$c" in --format|*"{{"*) continue ;; esac
                case "\$c" in
                    fx-api)    printf '/fx-api\trunning\tfixture-proj_cache\n' ;;
                    fx-db)     printf '/fx-db\trunning\tfixture-proj_pgdata\tfixture-proj_cache\n' ;;
                    other-api) printf '/other-api\texited\tother-proj_data\n' ;;
                    plain-box) printf '/plain-box\trunning\n' ;;
                esac
            done
            exit 0 ;;
        *"NetworkSettings.Networks"*)
            for c in "\$@"; do
                case "\$c" in --format|*"{{"*) continue ;; esac
                case "\$c" in
                    fx-api)    printf '/fx-api\tfixture-proj\tapi\trunning\tfixture-proj_default=172.18.0.5\tshared=10.10.0.5\n' ;;
                    fx-db)     printf '/fx-db\tfixture-proj\tdb\trunning\tfixture-proj_default=172.18.0.50\n' ;;
                    other-api) printf '/other-api\tother-proj\tapi\trunning\tother-proj_default=172.180.0.7\n' ;;
                    plain-box) printf '/plain-box\t\t\trunning\thost=invalid IP\n' ;;
                esac
            done
            exit 0 ;;
    esac
    for c in "\$@"; do
        case "\$c" in --format|*"{{"*) continue ;; esac
        case "\$c" in
            fx-api)    printf 'running\nfixture-proj\napi\n${WORK}/fake-project\n${WORK}/fake-project/docker-compose.yml,${WORK}/fake-project/docker-compose.override.yml\n' ;;
            fx-db)     printf 'exited\nfixture-proj\ndb\n${WORK}/fake-project\n${WORK}/fake-project/docker-compose.yml,${WORK}/fake-project/docker-compose.override.yml\n' ;;
            other-api) printf 'running\nother-proj\napi\n${WORK}/other-project\n${WORK}/other-project/docker-compose.yml\n' ;;
            plain-box) printf 'running\n\n\n\n\n' ;;
            *) exit 1 ;;
        esac
    done
    exit 0
fi

# dcrestart asks compose ps for each service's state and creation hash. Matched
# on config-hash, which nobody else requests, and BEFORE dcps' {{.Service}} arm
# below, which would otherwise answer with dcps' rows. Against fixtures/basic:
#   api     running, hash = what compose computes TODAY  -> nothing to warn
#   worker  exited,  hash = a stale one                  -> stopped AND drifted
#   db      no container at all                          -> skipped in silence
# api's hash is asked of the real compose, never hardcoded: it changes with the
# compose version, and a hardcoded one would turn api into "drifted" on the
# next upgrade.
case "\$*" in
    *"config-hash"*)
        cf=""; prev=""
        for a in "\$@"; do [ "\$prev" = "-f" ] && cf="\$a"; prev="\$a"; done
        h=\$("${REAL_DOCKER}" compose -f "\$cf" config --hash api 2>/dev/null)
        printf 'api\trunning\t%s\n' "\${h#* }"
        printf 'worker\texited\t0000stale0000\n'
        exit 0 ;;
esac
case "\$*" in
    *"{{.Names}}"*"{{.RunningFor}}"*)
        printf 'fx-api\ta1b2c3d4e5f6\tnginx:alpine\tUp 2 hours\t3 weeks ago\t2026-06-30 22:04:16 -0400 -04\t0.0.0.0:9080->9080/tcp, [::]:9080->9080/tcp\n'
        printf 'fx-db\tb2c3d4e5f6a1\tpostgres:18-alpine\tUp 2 hours (healthy)\tAbout an hour ago\t2026-07-23 01:00:00 -0400 -04\t5432/tcp\n'
        printf 'other-api\tc3d4e5f6a1b2\tquay.io/example/very-long-image-name:1.2.3\tUp 1 hour\t2 months ago\t2026-05-20 10:00:00 -0400 -04\t0.0.0.0:3001->3000/tcp, [::]:3001->3000/tcp\n'
        printf 'plain-box\td4e5f6a1b2c3\talpine:latest\tExited (137) 3 minutes ago\t5 days ago\t2026-07-18 08:00:00 -0400 -04\t\n'
        exit 0 ;;
    *"{{.Service}}"*)
        printf 'api\ta1b2c3d4e5f6\tnginx:alpine\tUp 2 hours\t3 weeks ago\t2026-06-30 22:04:16 -0400 -04\t127.0.0.1:8080->80/tcp\n'
        printf 'db\tb2c3d4e5f6a1\tpostgres:18-alpine\tUp 2 hours (unhealthy)\t5 days ago\t2026-07-18 08:00:00 -0400 -04\t5432/tcp\n'
        printf 'dns\tc3d4e5f6a1b2\tcoredns:1.11\tUp 2 hours\tAbout a minute ago\t2026-07-23 05:00:00 -0400 -04\t0.0.0.0:53->53/udp\n'
        exit 0 ;;
esac
# dprj asks ps for every container's compose labels. Matched on config_files,
# which only dprj requests from ps, and BEFORE the dver arm below: dver matches
# on the bare project label, which dprj's format also contains.
#   fixture-proj  api x2 replicas + db, all up, two files  -> running, "+1",
#                 and 3 containers but only 2 SERVICES — so a count of
#                 services and a count of containers can be told apart
#   other-proj    api up, worker exited                    -> partial
#   old-proj      web exited                               -> stopped
#   tmp-proj      lives under /tmp                         -> the reboot warning
#   (one container with no compose labels, which is not a project)
case "\$*" in
    *"project.config_files"*)
        printf 'fixture-proj\tapi\trunning\t/srv/fixture-proj\t/srv/fixture-proj/docker-compose.yml,/srv/fixture-proj/docker-compose.override.yml\n'
        printf 'fixture-proj\tapi\trunning\t/srv/fixture-proj\t/srv/fixture-proj/docker-compose.yml,/srv/fixture-proj/docker-compose.override.yml\n'
        printf 'fixture-proj\tdb\trunning\t/srv/fixture-proj\t/srv/fixture-proj/docker-compose.yml,/srv/fixture-proj/docker-compose.override.yml\n'
        printf 'other-proj\tapi\trunning\t/srv/other-proj\t/srv/other-proj/compose.yaml\n'
        printf 'other-proj\tworker\texited\t/srv/other-proj\t/srv/other-proj/compose.yaml\n'
        printf 'old-proj\tweb\texited\t/srv/old-proj\t/srv/old-proj/compose.yaml\n'
        printf 'tmp-proj\tsvc\trunning\t/tmp/scratch/tmp-proj\t/tmp/scratch/tmp-proj/compose.yaml\n'
        printf '\t\trunning\t\t\n'
        exit 0 ;;
esac
# drestart asks ps for running names with their compose project and service.
# plain-box is EXITED in this world (as in dps's), so it is not here — which is
# what lets "matches only a stopped container" be tested. A test needing a
# name that contains another adds it through DAV2_EXTRA_CONTAINER.
case "\$*" in
    *"{{.Names}}"*"compose.service"*)
        printf 'fx-api\tfixture-proj\tapi\n'
        printf 'fx-db\tfixture-proj\tdb\n'
        printf 'other-api\tother-proj\tapi\n'
        [ -n "\$DAV2_EXTRA_CONTAINER" ] && printf '%s\t\t\n' "\$DAV2_EXTRA_CONTAINER"
        exit 0 ;;
esac
# dver asks ps for names + the compose project label. Safe to match on the
# label alone: inspect (which also names it) was already settled above.
case "\$*" in
    *"com.docker.compose.project"*)
        printf 'fx-api\tfixture-proj\n'
        printf 'fx-db\tfixture-proj\n'
        printf 'other-api\tother-proj\n'
        printf 'plain-box\t\n'
        exit 0 ;;
esac
# devents: the event buffer, docker logs, and -f. The buffer carries the noise
# devents must drop — a healthcheck exec, a network event, another container —
# around fx-db's real story. -f gets a short stream that then ends, as if the
# user had pressed Ctrl-C.
case "\$1" in
    stats)
        # dstats/dcstats. Each rule has a row to bite on:
        #   fx-api     48% under --cpus 0.5        -> at its CPU ceiling, red
        #   fx-db      no memory limit, 120% CPU   -> "∞", more than a core
        #   other-api  240MiB/256MiB, 95/100 pids  -> near two limits, red
        #   dav2-fixture-basic-*  fixtures/basic's project, worker scaled to 2
        printf 'fx-api\t48.00%%\t150MiB / 256MiB\t1.2MB / 3.4MB\t10MB / 2MB\t12\n'
        printf 'fx-db\t120.50%%\t1.5GiB / 15.5GiB\t5MB / 1MB\t900MB / 2GB\t40\n'
        printf 'other-api\t2.00%%\t240MiB / 256MiB\t2kB / 1kB\t0B / 0B\t95\n'
        printf 'dav2-fixture-basic-api-1\t0.50%%\t20MiB / 15.5GiB\t1kB / 0B\t0B / 0B\t3\n'
        printf 'dav2-fixture-basic-worker-1\t0.10%%\t30MiB / 512MiB\t1kB / 0B\t0B / 0B\t2\n'
        printf 'dav2-fixture-basic-worker-2\t0.10%%\t31MiB / 512MiB\t1kB / 0B\t0B / 0B\t2\n'
        exit 0 ;;
    info)
        printf '8\t16000000000\n'
        exit 0 ;;
    events)
        now=\$(date +%s)
        case "\$*" in
        *"container=fx-db"*)
            printf '%s\tfx-db\t\t\texec_create: pg_isready -U app\n' "\$now"
            printf '%s\tfx-db\t\t15\tkill\n' "\$now"
            printf '%s\tfx-db\t143\t\tdie\n' "\$now" ;;
        *"type=container"*)
            printf '%s\tfx-db\t\t\texec_create: pg_isready -U app\n' "\$now"
            printf '%s\tfx-db\t\t15\tkill\n' "\$now"
            printf '%s\tother-api\t\t\tstart\n' "\$now" ;;
        *)
            printf '%s\tcontainer\tfx-api\t\t\texec_create: curl -f http://localhost/health\n' "\$((now-30))"
            printf '%s\tnetwork\tbridge\t\t\tconnect\n' "\$((now-25))"
            printf '%s\tcontainer\tfx-db\t\t9\tkill\n' "\$((now-20))"
            printf '%s\tcontainer\tfx-db\t\t\toom\n' "\$((now-20))"
            printf '%s\tcontainer\tfx-db\t137\t\tdie\n' "\$((now-20))"
            printf '%s\tcontainer\tother-api\t\t\tstart\n' "\$((now-10))"
            printf '%s\tcontainer\tfx-db\t\t\texec_die\n' "\$((now-5))" ;;
        esac
        exit 0 ;;
    logs)
        # Only devents' exact call. dlt's tests read "docker logs" back as
        # ARGV, so everything else must fall through to the capture below.
        case "\$*" in
            "logs --tail 5 --timestamps other-api")
                printf '2026-10-25T22:57:28.100000000Z fatal: cannot connect to db:5432\n'
                printf '2026-10-25T22:58:30.200000000Z fatal: giving up\n'
                exit 0 ;;
            "logs --tail 5 --timestamps "*)
                printf '2026-10-25T22:50:00.000000000Z FATAL: out of shared memory\n'
                exit 0 ;;
        esac ;;
esac
case "\$* " in
    *"ps -a "*|*"--format {{.Names}}"*)
        printf 'fx-api\nfx-db\nother-api\nplain-box\n'
        # A test that needs a name containing another one (devents' exact-name
        # rule) adds it here instead of changing the world everyone shares.
        [ -n "\$DAV2_EXTRA_CONTAINER" ] && printf '%s\n' "\$DAV2_EXTRA_CONTAINER"
        exit 0 ;;
esac
for a in "\$@"; do
    case "\$a" in
        config|ps) exec "${REAL_DOCKER}" "\$@" ;;
    esac
done
# A command that throws docker's stdout away (dprune does: hundreds of deleted
# IDs nobody reads) can still be checked: a test that sets DAV2_ARGV_LOG gets
# every captured argv appended there.
if [ -n "\$DAV2_ARGV_LOG" ]; then
    { printf 'ARGV:'; for a in "\$@"; do printf ' [%s]' "\$a"; done; printf '\n'; } >> "\$DAV2_ARGV_LOG"
fi
# dprune's refusal case: docker deletes the rest and refuses this one.
case " \$* " in
    *" rmi "*"busy/img:1"*)
        printf 'ARGV:'; for a in "\$@"; do printf ' [%s]' "\$a"; done; printf '\n'
        printf 'Error response from daemon: conflict: unable to remove repository reference "busy/img:1" (must force) - container 1234 is using its referenced image\n' >&2
        exit 1 ;;
    *" builder prune "*)
        printf 'Total:\t2.5GB\n'
        exit 0 ;;
esac
printf 'ARGV:'
for a in "\$@"; do printf ' [%s]' "\$a"; done
printf '\n'
SHIM
    chmod +x "${WORK}/bin/docker"
}
