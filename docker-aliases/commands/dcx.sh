#!/usr/bin/env bash
# docker-aliases — dcx: run a command (or open a shell) inside a service.
#
# Design contract for this command:
#   * With no command, dcx opens a shell — asking for bash and settling for sh.
#     Alpine images have no bash, and typing `dcx api bash`, reading "executable
#     file not found", then retyping `dcx api sh` is a tax paid daily.
#   * Flag parsing STOPS at the service pattern. Everything after it belongs to
#     the command, so `dcx api ls -la` passes -la to ls instead of choking on it.
#   * A pattern that matches several services is an error, not a guess. You can
#     only be inside one container, and picking one silently is how you end up
#     typing into the wrong shell.
#   * Preview, but no confirmation: this is interactive and used all day.

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------

_dcx_help() {
    printf "${CB}${CCY}dcx${CR} — run a command inside a Compose service\n\n"

    printf "${CCY}USAGE${CR}\n"
    printf "  ${CB}dcx${CR} [${CYE}flags${CR}] ${CMA}<pattern>${CR} [${CMA}command...${CR}]\n\n"

    printf "${CCY}FLAGS${CR}\n"
    printf "  ${CYE}-u${CR} ${CMA}<user>${CR}          Run as this user ${CI}(e.g. root)${CR}\n"
    printf "  ${CYE}-w${CR} ${CMA}<dir>${CR}           Start in this directory\n"
    printf "  ${CYE}-f${CR} ${CMA}<file>${CR}          Compose file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-e${CR} ${CMA}<file>${CR}          Env file to use ${CI}(repeatable)${CR}\n"
    printf "  ${CYE}-P${CR} ${CMA}<profile>${CR}       Compose profile ${CI}(repeatable, or comma-separated)${CR}\n"
    printf "  ${CYE}-h${CR}, ${CYE}--help${CR}         Show this help\n\n"

    printf "  ${CI}Flags must come BEFORE the pattern. Everything after the pattern${CR}\n"
    printf "  ${CI}is the command, so ${CR}${CGR}dcx api ls -la${CR}${CI} works as written.${CR}\n\n"

    printf "${CCY}THE SHELL${CR}\n"
    printf "  With no command, ${CB}dcx${CR} asks the container whether it has ${CB}bash${CR} and\n"
    printf "  opens it, falling back to ${CB}sh${CR}. Alpine images only ship sh.\n\n"

    printf "${CCY}PATTERNS${CR}\n"
    printf "  Patterns are ${CB}regular expressions${CR}, as in ${CB}dclt${CR} and ${CB}dcdown${CR} — but here\n"
    printf "  they must match ${CB}exactly one${CR} service. Several matches is an error.\n\n"

    printf "${CCY}EXAMPLES${CR}\n"
    printf "  ${CGR}dcx api${CR}                           Open a shell in 'api'\n"
    printf "  ${CGR}dcx '^api\$'${CR}                       Exactly the service named 'api'\n"
    printf "  ${CGR}dcx api ls -la /app${CR}               Run a command with its own flags\n"
    printf "  ${CGR}dcx -u root api${CR}                   Shell in as root\n"
    printf "  ${CGR}dcx -w /app api npm test${CR}          Run from a directory\n"
    printf "  ${CGR}dcx api cat /etc/hosts | grep db${CR}  Pipe it — the TTY is dropped for you\n"
}

# ---------------------------------------------------------------------------
# dcx
# ---------------------------------------------------------------------------

dcx() {
    case "$1" in
        -h|--help) _dcx_help; return 0 ;;
    esac

    # --- parse --------------------------------------------------------------
    # No short-flag clustering here: -u and -w both take values, and everything
    # after the pattern is somebody else's argv. Clustering would only create
    # ways to misread a command.
    local user="" workdir=""
    local files=() env_files=() profiles=()
    local pattern="" command_args=()
    local profile_item

    while [[ $# -gt 0 ]]; do
        # Once the pattern is known, stop interpreting: the rest is the command.
        if [[ -n "$pattern" ]]; then
            command_args+=("$1")
            shift
            continue
        fi

        case "$1" in
            -h|--help) _dcx_help; return 0 ;;
            -u)
                shift
                [[ $# -eq 0 ]] && { _err dcx "-u requires a user"; return 1; }
                user="$1"
                ;;
            -w)
                shift
                [[ $# -eq 0 ]] && { _err dcx "-w requires a directory"; return 1; }
                workdir="$1"
                ;;
            -f)
                shift
                [[ $# -eq 0 ]] && { _err dcx "-f requires a compose file"; return 1; }
                files+=("$1")
                ;;
            -e)
                shift
                [[ $# -eq 0 ]] && { _err dcx "-e requires an env file"; return 1; }
                env_files+=("$1")
                ;;
            -P)
                shift
                [[ $# -eq 0 ]] && { _err dcx "-P requires a profile"; return 1; }
                while IFS= read -r profile_item; do
                    [[ -n "$profile_item" ]] && profiles+=("$profile_item")
                done <<< "$(_split_commas "$1")"
                ;;
            --) ;;   # optional separator, simply consumed
            -*) _err dcx "unknown flag: $1  (flags go before the pattern)"; return 1 ;;
            *)  pattern="$1" ;;
        esac
        shift
    done

    if [[ -z "$pattern" ]]; then
        _err dcx "a service pattern is required  (try: dcx --help)"
        return 1
    fi

    # --- resolve and validate inputs ---------------------------------------
    local file
    if [[ ${#files[@]} -eq 0 ]]; then
        local resolved resolved_item
        resolved=$(_resolve_compose_files) || {
            _err dcx "no compose file found — add docker-compose.yml or set DOCKER_COMPOSE_FILE"
            return 1
        }
        # May be two lines: the base file and its override sibling.
        while IFS= read -r resolved_item; do
            [[ -n "$resolved_item" ]] && files+=("$resolved_item")
        done <<< "$resolved"
    else
        for file in "${files[@]}"; do
            [[ -f "$file" ]] || { _err dcx "compose file not found: $file"; return 1; }
        done
    fi

    for file in "${env_files[@]}"; do
        [[ -f "$file" ]] || { _err dcx "env file not found: $file"; return 1; }
    done

    # --- match exactly one service -----------------------------------------
    local services=() svc
    while IFS= read -r svc; do
        [[ -n "$svc" ]] && services+=("$svc")
    done <<< "$(_get_compose_services --profiles "${profiles[*]}" "${files[@]}")"

    if [[ ${#services[@]} -eq 0 ]]; then
        _err dcx "no services found in the compose file"
        return 1
    fi

    local matched=()
    for svc in "${services[@]}"; do
        if [[ "$svc" =~ $pattern ]]; then
            matched+=("$svc")
        fi
    done

    if [[ ${#matched[@]} -eq 0 ]]; then
        _err dcx "no service matched: $pattern"
        printf "  ${CDIM}available:${CR} ${CMA}%s${CR}\n" "${services[*]}" >&2
        return 1
    fi

    if [[ ${#matched[@]} -gt 1 ]]; then
        # Deliberately not a guess. You can only be inside one container, and
        # silently choosing one is how you type into the wrong shell.
        local first=""
        for svc in "${matched[@]}"; do first="$svc"; break; done
        _err dcx "'$pattern' matched ${#matched[@]} services"
        printf "  ${CMA}%s${CR}\n" "${matched[*]}" >&2
        printf "  ${CDIM}→ narrow the pattern, or use '^%s\$'${CR}\n" "$first" >&2
        return 1
    fi

    local target=""
    for svc in "${matched[@]}"; do target="$svc"; break; done

    # --- base command (shared by the probe and the real run) ----------------
    local base=(docker compose)
    local shown="${CDIM}docker compose${CR}"
    local item

    for item in "${files[@]}"; do
        base+=(-f "$item")
        shown+=" ${CDIM}-f${CR} ${CWH}${item}${CR}"
    done
    for item in "${env_files[@]}"; do
        base+=(--env-file "$item")
        shown+=" ${CDIM}--env-file${CR} ${CWH}${item}${CR}"
    done
    for item in "${profiles[@]}"; do
        base+=(--profile "$item")
        shown+=" ${CDIM}--profile${CR} ${CBL}${item}${CR}"
    done

    # --- decide the command -------------------------------------------------
    # With nothing to run, ask the container what shell it actually has. This
    # costs one extra round trip, and buys a preview that names the real shell
    # instead of a wrapper nobody wants to read.
    if [[ ${#command_args[@]} -eq 0 ]]; then
        if "${base[@]}" exec -T "$target" sh -c 'command -v bash' >/dev/null 2>&1; then
            command_args=(bash)
        else
            command_args=(sh)
        fi
    fi

    # --- assemble -----------------------------------------------------------
    local cmd=("${base[@]}" exec)
    shown+=" ${CCY}${CB}exec${CR}"

    local flags_line=""

    # A TTY is only useful when there is a terminal on both ends. Allocating one
    # into a pipe is what makes `dcx api ls | grep x` misbehave.
    if [[ ! -t 0 || ! -t 1 ]]; then
        cmd+=(--no-tty)
        shown+=" ${CYE}--no-tty${CR}"
        flags_line+=" --no-tty"
    fi
    if [[ -n "$user" ]]; then
        cmd+=(--user "$user")
        shown+=" ${CYE}--user ${user}${CR}"
        flags_line+=" --user $user"
    fi
    if [[ -n "$workdir" ]]; then
        cmd+=(--workdir "$workdir")
        shown+=" ${CYE}--workdir ${workdir}${CR}"
        flags_line+=" --workdir $workdir"
    fi

    cmd+=("$target")
    shown+=" ${CMA}${target}${CR}"

    for item in "${command_args[@]}"; do
        cmd+=("$item")
        shown+=" ${CWH}${item}${CR}"
    done

    # --- preview, then run --------------------------------------------------
    # No confirmation: opening a shell changes nothing by itself, and this is
    # the command you reach for dozens of times a day.
    local files_display
    files_display=$(printf '%s\n' "${files[@]}")

    _render_preview "compose exec" "$files_display" "$target" "${flags_line# }" "$shown"

    "${cmd[@]}"
}
