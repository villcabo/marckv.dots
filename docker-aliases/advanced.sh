#!/usr/bin/env bash
# Advanced docker compose functions: dcpr (git.properties) and dip (container IPs)

# ---------------------------------------------------------------------------
# dcpr — Show git.properties from running compose containers
#
# Usage:
#   dcpr <service>          Show git.properties for one service
#   dcpr -a                 Show git.properties for all services
#   dcpr -a -s              Show summary table for all services
#   dcpr -as / dcpr -sa     Shorthand for -a -s
# ---------------------------------------------------------------------------
dcpr() {
    local show_all=false show_summary=false
    local services=()

    local compose_file
    compose_file=$(_get_compose_file) || {
        echo -e "${CRE}No compose file found ❌"
        return 1
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)        show_all=true ;;
            -s|--summary)    show_summary=true ;;
            -as|-sa)         show_all=true; show_summary=true ;;
            --)              shift; break ;;
            -*) echo "❌ Unknown option: $1" >&2; return 1 ;;
            *)  services+=("$1") ;;
        esac
        shift
    done

    local _git_props_cmd='
        if [ -f /app/resources/git.properties ]; then
            cat /app/resources/git.properties
        elif [ -f /usr/share/nginx/html/git.properties ]; then
            cat /usr/share/nginx/html/git.properties
        else
            echo "❌ git.properties not found"
        fi'

    if [[ "$show_all" == true ]]; then
        local all_services
        all_services=($(_get_compose_services))
        if [[ ${#all_services[@]} -eq 0 ]]; then
            echo "❌ No compose services found."
            return 1
        fi

        if [[ "$show_summary" == true ]]; then
            printf "Processing services...\n" >&2

            local -a rows
            local max_service=12 max_commit=9 max_email=9 max_branch=6 max_msg=13

            for svc in "${all_services[@]}"; do
                printf "Processing: %s\r" "$svc" >&2
                local props
                props=$(docker compose -f "$compose_file" exec "$svc" sh -c "$_git_props_cmd" 2>/dev/null)
                [[ -z "$props" ]] && continue

                local branch commit_id user_email commit_msg
                commit_id=$(echo "$props" | grep -E '^git\.commit.id='          | head -1 | cut -d= -f2-)
                user_email=$(echo "$props" | grep -E '^git\.commit.user.email=' | head -1 | cut -d= -f2-)
                branch=$(echo "$props"     | grep -E '^git\.branch='            | head -1 | cut -d= -f2-)
                commit_msg=$(echo "$props" | grep -E '^git\.commit.message.full='  | head -1 | cut -d= -f2-)
                [[ -z "$commit_msg" ]] && commit_msg=$(echo "$props" | grep -E '^git\.commit.message.short=' | head -1 | cut -d= -f2-)
                commit_msg=$(echo "$commit_msg" | tr '\n' ' ' | tr -s ' ')

                rows+=("$svc|$commit_id|$user_email|$branch|$commit_msg")
                (( ${#svc}        > max_service )) && max_service=${#svc}
                (( ${#commit_id}  > max_commit  )) && max_commit=${#commit_id}
                (( ${#user_email} > max_email   )) && max_email=${#user_email}
                (( ${#branch}     > max_branch  )) && max_branch=${#branch}
                (( ${#commit_msg} > max_msg     )) && max_msg=${#commit_msg}
            done

            (( max_msg > 60 )) && max_msg=60

            local total_width=$(( max_service + max_commit + max_email + max_branch + max_msg + 13 ))
            printf -- '%*s\n' "$total_width" '' | tr ' ' '-'
            printf "%-${max_service}s | %-${max_commit}s | %-${max_email}s | %-${max_branch}s | %-${max_msg}s\n" \
                "SERVICE_NAME" "COMMIT_ID" "USER_EMAIL" "BRANCH" "COMMIT_MESSAGE"
            printf -- '%*s\n' "$total_width" '' | tr ' ' '-'

            for row in "${rows[@]}"; do
                IFS='|' read -r svc commit_id user_email branch commit_msg <<< "$row"
                [[ ${#commit_msg} -gt $max_msg ]] && commit_msg="${commit_msg:0:$max_msg}"
                printf "%-${max_service}s | %-${max_commit}s | %-${max_email}s | %-${max_branch}s | %-${max_msg}s\n" \
                    "$svc" "$commit_id" "$user_email" "$branch" "$commit_msg"
            done
            printf "\n" >&2
        else
            for svc in "${all_services[@]}"; do
                echo "# $svc"
                docker compose -f "$compose_file" exec "$svc" sh -c "$_git_props_cmd"
                echo
            done
        fi
        return 0
    fi

    if [[ ${#services[@]} -eq 0 ]]; then
        echo "Usage: dcpr <service> | dcpr -a | dcpr -a -s"
        return 1
    fi

    docker compose -f "$compose_file" exec "${services[0]}" sh -c "$_git_props_cmd"
}
