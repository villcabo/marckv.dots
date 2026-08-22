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
# di asks for images and for the reclaimable figure. The invented world mirrors
# the shape that matters: tagged images with and without containers, plus
# dangling ones — which the real docker HIDES from a plain `images` call and
# only returns for `-f dangling=true`.
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
case "\$* " in
    *"ps -a "*|*"--format {{.Names}}"*)
        printf 'fx-api\nfx-db\nother-api\nplain-box\n'; exit 0 ;;
esac
for a in "\$@"; do
    case "\$a" in
        config|ps) exec "${REAL_DOCKER}" "\$@" ;;
    esac
done
printf 'ARGV:'
for a in "\$@"; do printf ' [%s]' "\$a"; done
printf '\n'
SHIM
    chmod +x "${WORK}/bin/docker"
}
