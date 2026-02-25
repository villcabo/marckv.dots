# ------------------------------------------------------------------
# alias grdev="gradle -PdevArgs"

# Initialize shared color palette.
# Uses tput when terminal capabilities are available; otherwise falls back to ANSI escape codes.
_grdev_init_colors() {
    # Default ANSI fallback (current behavior).
    GRDEV_RED='\033[0;31m'
    GRDEV_GREEN='\033[0;32m'
    GRDEV_YELLOW='\033[1;33m'
    GRDEV_BLUE='\033[0;34m'
    GRDEV_PURPLE='\033[0;35m'
    GRDEV_CYAN='\033[0;36m'
    GRDEV_WHITE='\033[1;37m'
    GRDEV_BOLD='\033[1m'
    GRDEV_NC='\033[0m'
    GRDEV_BRIGHT_GREEN='\033[1;32m'
    GRDEV_BRIGHT_RED='\033[1;31m'
    GRDEV_BRIGHT_YELLOW='\033[1;33m'
    GRDEV_BRIGHT_BLUE='\033[1;34m'
    GRDEV_BRIGHT_CYAN='\033[1;36m'
    GRDEV_BRIGHT_PURPLE='\033[1;35m'

    # Prefer terminal capabilities when available.
    if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" ]]; then
        local color_count
        color_count="$(tput colors 2>/dev/null || echo 0)"
        if [[ "$color_count" =~ ^[0-9]+$ ]] && (( color_count >= 8 )); then
            local tput_bold tput_reset
            tput_bold="$(tput bold 2>/dev/null)"
            tput_reset="$(tput sgr0 2>/dev/null)"

            GRDEV_RED="$(tput setaf 1 2>/dev/null)"
            GRDEV_GREEN="$(tput setaf 2 2>/dev/null)"
            GRDEV_YELLOW="$(tput setaf 3 2>/dev/null)"
            GRDEV_BLUE="$(tput setaf 4 2>/dev/null)"
            GRDEV_PURPLE="$(tput setaf 5 2>/dev/null)"
            GRDEV_CYAN="$(tput setaf 6 2>/dev/null)"
            GRDEV_WHITE="$(tput setaf 7 2>/dev/null)"
            GRDEV_BOLD="$tput_bold"
            GRDEV_NC="$tput_reset"
            GRDEV_BRIGHT_GREEN="${tput_bold}$(tput setaf 2 2>/dev/null)"
            GRDEV_BRIGHT_RED="${tput_bold}$(tput setaf 1 2>/dev/null)"
            GRDEV_BRIGHT_YELLOW="${tput_bold}$(tput setaf 3 2>/dev/null)"
            GRDEV_BRIGHT_BLUE="${tput_bold}$(tput setaf 4 2>/dev/null)"
            GRDEV_BRIGHT_CYAN="${tput_bold}$(tput setaf 6 2>/dev/null)"
            GRDEV_BRIGHT_PURPLE="${tput_bold}$(tput setaf 5 2>/dev/null)"
        fi
    fi
}

_grdev_init_colors

# Directory where environment files live (can be overridden by the user)
GRDEV_ENVIRONMENTS_DIR="${GRDEV_ENVIRONMENTS_DIR:-$HOME/.grdev/environments}"

# Function to display help information
show_help() {
    local GREEN="$GRDEV_GREEN"
    local YELLOW="$GRDEV_YELLOW"
    local BLUE="$GRDEV_BLUE"
    local CYAN="$GRDEV_CYAN"
    local WHITE="$GRDEV_WHITE"
    local BOLD="$GRDEV_BOLD"
    local NC="$GRDEV_NC"
    local BRIGHT_GREEN="$GRDEV_BRIGHT_GREEN"
    local BRIGHT_BLUE="$GRDEV_BRIGHT_BLUE"
    local BRIGHT_CYAN="$GRDEV_BRIGHT_CYAN"
    
    echo -e "${BRIGHT_BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BRIGHT_CYAN}${BOLD}                         GRDEV - Gradle Development Tool${NC}"
    echo -e "${BRIGHT_BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}DESCRIPTION:${NC}"
    echo -e "  Enhanced Gradle runner with Spring Boot support, colorized output,"
    echo -e "  and intelligent test detection. Supports multiple execution modes."
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}USAGE:${NC}"
    echo -e "  ${CYAN}grdev${NC} ${YELLOW}[directory]${NC} ${WHITE}[options]${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}EXECUTION MODES:${NC}"
    echo -e "  ${CYAN}grdev${NC}                    ${WHITE}# Compile and run JAR (default mode)${NC}"
    echo -e "  ${CYAN}grdev${NC} ${YELLOW}project${NC}           ${WHITE}# Same but in 'project' directory${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-r${NC}                 ${WHITE}# Run existing JAR only${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-d${NC}                 ${WHITE}# Development mode (bootRun)${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}OPTIONS:${NC}"
    echo -e "  ${BLUE}-r${NC}, ${BLUE}--run${NC}               Run existing JAR file (skip compilation)"
    echo -e "  ${BLUE}-d${NC}, ${BLUE}--dev${NC}               Development mode using bootRun"
    echo -e "  ${BLUE}-y${NC}, ${BLUE}--yes${NC}               Auto-confirm all dialogs"
    echo -e "  ${BLUE}-n${NC}, ${BLUE}--no-clean${NC}          Skip clean step (dev and build modes)"
    echo -e "  ${BLUE}-p${NC}, ${BLUE}--profile${NC} ${YELLOW}<name>${NC}    Specify Spring profile (default: dev)"
    echo -e "  ${BLUE}-e${NC}, ${BLUE}--env${NC} ${YELLOW}<name>${NC}        Load extra properties from ~/.grdev/environments/<name>"
    echo -e "  ${BLUE}--no-liquibase${NC}         Add no-liquibase to active Spring profile(s)"
    echo -e "  ${BLUE}-h${NC}, ${BLUE}--help${NC}              Show this help message"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}COMBINED OPTIONS:${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dy${NC}               ${WHITE}# Dev mode + auto-confirm${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-ry${NC}               ${WHITE}# Run JAR + auto-confirm${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dny${NC}              ${WHITE}# Dev mode + no clean + auto-confirm${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}PROFILE EXAMPLES:${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-p${NC} ${YELLOW}prod${NC}            ${WHITE}# Use production profile${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dy${NC} ${BLUE}-p${NC} ${YELLOW}test${NC}        ${WHITE}# Dev mode with test profile${NC}"
    echo -e "  ${CYAN}grdev${NC} ${YELLOW}auth-service${NC} ${BLUE}-dny${NC} ${BLUE}-p${NC} ${YELLOW}local${NC}  ${WHITE}# Full example${NC}"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}ENVIRONMENTS:${NC}"
    echo -e "  Files in ${YELLOW}~/.grdev/environments/${NC} hold extra properties injected at runtime."
    echo -e "  Format: ${WHITE}key=value${NC} lines (comments with ${CYAN}#${NC} are ignored)."
    echo -e "  Properties are passed as ${CYAN}-Dkey=value${NC} JVM flags (jar/bootRun)."
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}FEATURES:${NC}"
    echo -e "  ${WHITE}•${NC} Automatic test task detection and exclusion"
    echo -e "  ${WHITE}•${NC} Spring Boot banner suppression"
    echo -e "  ${WHITE}•${NC} Colorized output with progress indicators"
    echo -e "  ${WHITE}•${NC} Smart Gradle wrapper detection"
    echo -e "  ${WHITE}•${NC} Directory-specific execution"
    echo -e "  ${WHITE}•${NC} Spring profile support (default: dev)"
    echo -e "  ${WHITE}•${NC} Environment files for extra runtime properties"
    echo ""
    echo -e "${BRIGHT_GREEN}${BOLD}EXAMPLES:${NC}"
    echo -e "  ${CYAN}grdev${NC}                           ${WHITE}# Simple compile and run${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dy${NC}                      ${WHITE}# Fast dev mode${NC}"
    echo -e "  ${CYAN}grdev${NC} ${YELLOW}payment-service${NC} ${BLUE}-ry${NC}          ${WHITE}# Run JAR in specific project${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dny${NC} ${BLUE}-p${NC} ${YELLOW}test${NC}               ${WHITE}# Dev mode, no clean, test profile${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-p${NC} ${YELLOW}prod${NC} ${BLUE}-y${NC}               ${WHITE}# Production profile, auto-confirm${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-e${NC} ${YELLOW}qadb${NC}                    ${WHITE}# Load ~/.grdev/environments/qadb props${NC}"
    echo -e "  ${CYAN}grdev${NC} ${BLUE}-dy${NC} ${BLUE}-e${NC} ${YELLOW}qadb${NC} ${BLUE}-p${NC} ${YELLOW}qa${NC}         ${WHITE}# Dev mode with qa env + profile${NC}"
    echo ""
    echo -e "${BRIGHT_BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

# Enhanced grdev method with colors and improved formatting
# Usage: 
#   grdev                    - Compile and run JAR in current directory (default: dev profile)
#   grdev [directory]        - Compile and run JAR in specified directory
#   grdev [-r|--run]         - Run existing JAR in current directory
#   grdev [directory] -r     - Run existing JAR in specified directory
#   grdev [-d|--dev]         - Run with clean bootRun in current directory
#   grdev [directory] -d     - Run with clean bootRun in specified directory
#   grdev [-y|--yes]         - Auto-confirm all dialogs
#   grdev [-n|--no-clean]    - Skip clean step (affects build and -d/--dev modes)
#   grdev [-p|--profile] <profile> - Specify Spring profile (default: dev)
#   grdev [--no-liquibase]   - Add no-liquibase profile
#   grdev [-h|--help]        - Show detailed help information
#
# Combined options examples:
#   grdev -dy                - Dev mode with auto-confirm
#   grdev -ry                - Run JAR with auto-confirm  
#   grdev -dny               - Dev mode, no clean, auto-confirm
#   grdev -p prod            - Use 'prod' profile
#   grdev -dy -p test        - Dev mode, auto-confirm, test profile
#   grdev project -dny -p local - Dev mode in 'project' directory, no clean, auto-confirm, local profile
#   grdev --help             - Display comprehensive help
function grdev {
    # Color and style definitions
    local RED="$GRDEV_RED"
    local GREEN="$GRDEV_GREEN"
    local YELLOW="$GRDEV_YELLOW"
    local BLUE="$GRDEV_BLUE"
    local PURPLE="$GRDEV_PURPLE"
    local CYAN="$GRDEV_CYAN"
    local WHITE="$GRDEV_WHITE"
    local BOLD="$GRDEV_BOLD"
    local NC="$GRDEV_NC" # No Color
    local BRIGHT_GREEN="$GRDEV_BRIGHT_GREEN"
    local BRIGHT_RED="$GRDEV_BRIGHT_RED"
    local BRIGHT_YELLOW="$GRDEV_BRIGHT_YELLOW"
    local BRIGHT_BLUE="$GRDEV_BRIGHT_BLUE"
    local BRIGHT_CYAN="$GRDEV_BRIGHT_CYAN"
    local BRIGHT_PURPLE="$GRDEV_BRIGHT_PURPLE"
    
    # Parse arguments to determine directory and options
    local TARGET_DIR=""
    local RUN_ONLY=false
    local DEV_MODE=false
    local AUTO_YES=false
    local NO_CLEAN=false
    local NO_LIQUIBASE=false
    local SPRING_PROFILE="dev"  # Default profile
    local EFFECTIVE_SPRING_PROFILE=""
    local ENV_NAME=""
    local ENV_JVM_PROPS=""      # -Dkey=value flags for direct java -jar calls
    local ENV_SPRING_ARGS=""    # --key=value flags for bootRun --args
    local ENV_VARS_LIST=()      # display list: "key=value"
    local ORIGINAL_DIR=$(pwd)
    
    # Check for help first (simple approach)
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            show_help
            return 0
        fi
    done
    
    # Process other arguments
    while [[ $# -gt 0 ]]; do
        local arg="$1"
        case $arg in
            --run)
                RUN_ONLY=true
                shift
                ;;
            --dev)
                DEV_MODE=true
                shift
                ;;
            --yes)
                AUTO_YES=true
                shift
                ;;
            --no-clean)
                NO_CLEAN=true
                shift
                ;;
            --no-liquibase)
                NO_LIQUIBASE=true
                shift
                ;;
            --env)
                shift
                if [[ $# -gt 0 ]]; then
                    ENV_NAME="$1"
                    shift
                else
                    echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}--env requires an environment name${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                    return 1
                fi
                ;;
            -h|--help)
                show_help
                return 0
                ;;
            -p|--profile)
                shift
                if [[ $# -gt 0 ]]; then
                    SPRING_PROFILE="$1"
                    shift
                else
                    echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}--profile requires a profile name${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                    return 1
                fi
                ;;
            -*)
                # Handle combined short options like -dy, -ry, -dny, etc.
                local options="${arg#-}"  # Remove leading dash
                local j=0
                while [ $j -lt ${#options} ]; do
                    local opt="${options:$j:1}"
                    case $opt in
                        r)
                            RUN_ONLY=true
                            ;;
                        d)
                            DEV_MODE=true
                            ;;
                        y)
                            AUTO_YES=true
                            ;;
                        n)
                            NO_CLEAN=true
                            ;;
                        h)
                            show_help
                            return 0
                            ;;
                        p)
                            # Handle -p in combined options (next argument should be profile)
                            if [ $((j + 1)) -lt ${#options} ]; then
                                echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}-p must be the last option in combined options${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                                echo -e "${CYAN}Use: grdev -dy -p prod  (not grdev -dyp prod)${NC}"
                                return 1
                            fi
                            shift
                            if [[ $# -gt 0 ]]; then
                                SPRING_PROFILE="$1"
                            else
                                echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}-p requires a profile name${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                                return 1
                            fi
                            ;;
                        e)
                            # Handle -e in combined options (next argument should be env name)
                            if [ $((j + 1)) -lt ${#options} ]; then
                                echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}-e must be the last option in combined options${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                                echo -e "${CYAN}Use: grdev -dy -e qadb  (not grdev -dye qadb)${NC}"
                                return 1
                            fi
                            shift
                            if [[ $# -gt 0 ]]; then
                                ENV_NAME="$1"
                            else
                                echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}-e requires an environment name${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                                return 1
                            fi
                            ;;
                        *)
                            echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Unknown option: -$opt${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                            echo -e "${CYAN}Usage: grdev [directory] [-r|--run] [-d|--dev] [-y|--yes] [-n|--no-clean] [--no-liquibase] [-p|--profile <profile>] [-h|--help]${NC}"
                            echo -e "${CYAN}Examples: grdev -dy, grdev -ry, grdev -dny, grdev -p prod, grdev --help${NC}"
                            return 1
                            ;;
                    esac
                    ((j++))
                done
                shift
                ;;
            *)
                if [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$arg"
                    shift
                else
                    echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Multiple directories specified${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                    return 1
                fi
                ;;
        esac
    done
    
    # Validate argument combinations
    if [[ "$RUN_ONLY" == true && "$DEV_MODE" == true ]]; then
        echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Cannot use both -r/--run and -d/--dev options together${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
        return 1
    fi
    
    # Handle --no-clean option: not applicable when only running an existing JAR
    if [[ "$NO_CLEAN" == true && "$RUN_ONLY" == true ]]; then
        echo -e "${BRIGHT_YELLOW}${BOLD}Note: ${NC}${YELLOW}--no-clean option ignored when using -r/--run${NC} ⚠️"
        NO_CLEAN=false
    fi

    # Build effective profile value to be used in Spring commands
    EFFECTIVE_SPRING_PROFILE="$SPRING_PROFILE"
    if [[ "$NO_LIQUIBASE" == true ]]; then
        if [[ "$DEV_MODE" == true ]]; then
            EFFECTIVE_SPRING_PROFILE="${SPRING_PROFILE},no-liquibase"
        else
            EFFECTIVE_SPRING_PROFILE="no-liquibase"
        fi
    fi
    
    # Load environment file if -e/--env was specified
    if [[ -n "$ENV_NAME" ]]; then
        local env_file="$GRDEV_ENVIRONMENTS_DIR/$ENV_NAME"
        if [[ ! -d "$GRDEV_ENVIRONMENTS_DIR" ]]; then
            echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Environments directory not found: $GRDEV_ENVIRONMENTS_DIR${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
            echo -e "${CYAN}Create it with: ${BOLD}mkdir -p $GRDEV_ENVIRONMENTS_DIR${NC}"
            return 1
        fi
        if [[ ! -f "$env_file" ]]; then
            echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Environment file not found: $env_file${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
            local available
            available=$(ls "$GRDEV_ENVIRONMENTS_DIR" 2>/dev/null)
            if [[ -n "$available" ]]; then
                echo -e "${CYAN}Available environments:${NC}"
                while IFS= read -r f; do
                    echo -e "  ${YELLOW}• $f${NC}"
                done <<< "$available"
            else
                echo -e "${YELLOW}No environment files found in $GRDEV_ENVIRONMENTS_DIR${NC}"
            fi
            return 1
        fi
        # Parse KEY=VALUE lines; skip blanks and comments
        # Uses parameter expansion (no BASH_REMATCH) for bash/zsh compatibility
        while IFS= read -r line; do
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${line// }" ]] && continue
            [[ "$line" != *=* ]] && continue
            local _key="${line%%=*}"
            local _val="${line#*=}"
            # Validate key: letter/underscore start, then alphanumeric/dot/dash/underscore
            [[ ! "$_key" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] && continue
            # Strip surrounding double quotes
            if [[ "${_val}" == '"'*'"' ]]; then
                _val="${_val#\"}"
                _val="${_val%\"}"
            fi
            # Strip surrounding single quotes
            if [[ "${_val}" == "'"*"'" ]]; then
                _val="${_val#\'}"
                _val="${_val%\'}"
            fi
            # Escape value for eval (handles !, $, spaces, etc.) - command substitution avoids printf -v portability issues
            local _val_q
            _val_q="$(printf '%q' "$_val")"
            ENV_JVM_PROPS="$ENV_JVM_PROPS -D${_key}=${_val_q}"
            ENV_SPRING_ARGS="$ENV_SPRING_ARGS --${_key}=${_val_q}"
            ENV_VARS_LIST+=("${_key}=${_val}")
        done < "$env_file"
    fi

    # Set working directory
    if [[ -n "$TARGET_DIR" ]]; then
        if [[ -d "$TARGET_DIR" ]]; then
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${PURPLE}Changing to directory:${NC} ${BOLD}${YELLOW}$TARGET_DIR${NC}"
            cd "$TARGET_DIR" || {
                echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Cannot access directory: $TARGET_DIR${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
                return 1
            }
        else
            echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}Directory does not exist: $TARGET_DIR${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
            return 1
        fi
    fi
    
    local CURRENT_DIR=$(pwd)
    local BUILD_DIR="$CURRENT_DIR/build/libs"
    local GRADLE_CMD=""
    local TEST_TASKS=""
    
    # Show current working directory
    echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${GREEN}Working in directory:${NC} ${BOLD}${WHITE}$CURRENT_DIR${NC}"
    echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${PURPLE}Spring profile:${NC} ${BOLD}${YELLOW}$EFFECTIVE_SPRING_PROFILE${NC}"
    if [[ -n "$ENV_NAME" ]]; then
        echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${PURPLE}Environment file:${NC} ${BOLD}${YELLOW}$ENV_NAME${NC} ${CYAN}($GRDEV_ENVIRONMENTS_DIR/$ENV_NAME)${NC}"
        for _var in "${ENV_VARS_LIST[@]}"; do
            echo -e "    ${CYAN}•${NC} ${WHITE}$_var${NC}"
        done
    fi

    # List of common test tasks to check
    local COMMON_TEST_TASKS="test|integrationTest|functionalTest|acceptanceTest|unitTest|e2eTest|smokeTest|contractTest|performanceTest|testIntegration|check|webapp|webapp_test"

    # Determine which Gradle command to use
    if [[ -f "./gradlew" ]]; then
        GRADLE_CMD="./gradlew"
        echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${GREEN}Using project Gradle wrapper${NC} ${BOLD}(./gradlew)${NC}"
    elif command -v gradle &> /dev/null; then
        GRADLE_CMD="gradle"
        echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${GREEN}Using system Gradle${NC}"
    else
        echo -e "${BRIGHT_RED}${BOLD}Error: ${NC}${RED}No Gradle found. Please install Gradle or ensure gradlew exists.${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
        return 1
    fi

    # Function to detect test tasks in all .gradle files recursively
    detect_test_tasks() {
        local TEST_EXCLUDE_LIST=""
        local FOUND_TASKS=()
        
        echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${PURPLE}Scanning all Gradle files for test tasks...${NC}"
        
        # Check which common tasks exist using simple array
        local TASK_LIST=(${(s:|:)COMMON_TEST_TASKS})
        
        # Function to search for tasks in a file
        search_tasks_in_file() {
            local file="$1"
            local found_in_file=false
            
            for task in "${TASK_LIST[@]}"; do
                if grep -q "\b$task\b" "$file" 2>/dev/null; then
                    if [[ ! " ${FOUND_TASKS[@]} " =~ " ${task} " ]]; then
                        FOUND_TASKS+=("$task")
                        TEST_EXCLUDE_LIST="$TEST_EXCLUDE_LIST -x $task"
                        local relative_path="${file#$CURRENT_DIR/}"
                        [[ "$relative_path" == "$file" ]] && relative_path=$(basename "$file")
                        echo -e "  ${GREEN}Found task:${NC} ${BOLD}${YELLOW}$task${NC} ${CYAN}(in $relative_path)${NC} ${BRIGHT_GREEN}${BOLD}✓${NC}"
                        found_in_file=true
                    fi
                fi
            done
            
            return $([[ "$found_in_file" == true ]] && echo 0 || echo 1)
        }
        
        # Find all .gradle and .gradle.kts files recursively
        local gradle_files_found=false
        
        # Search for .gradle files
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                search_tasks_in_file "$file"
                gradle_files_found=true
            fi
        done < <(find "$CURRENT_DIR" -name "*.gradle" -type f -print0 2>/dev/null)
        
        # Search for .gradle.kts files (Kotlin DSL)
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                search_tasks_in_file "$file"
                gradle_files_found=true
            fi
        done < <(find "$CURRENT_DIR" -name "*.gradle.kts" -type f -print0 2>/dev/null)
        
        # Report results
        if [[ "$gradle_files_found" == false ]]; then
            echo -e "  ${YELLOW}No Gradle files found in project${NC}"
        fi
        
        # Provide summary and defaults
        if [[ -z "$TEST_EXCLUDE_LIST" ]]; then
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${YELLOW}No common test tasks found, using default exclusions${NC}"
            TEST_EXCLUDE_LIST="-x test -x integrationTest"
        else
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${CYAN}Test tasks to exclude:${NC}${BOLD}$TEST_EXCLUDE_LIST${NC}"
        fi
        
        echo "$TEST_EXCLUDE_LIST"
    }

    # Function to ask for user confirmation
    ask_confirmation() {
        local action_description="$1"
        local command_preview="$2"

        echo -e "\n${BRIGHT_BLUE}${BOLD}Action to perform: ${NC}${CYAN}${BOLD}$action_description${NC} 📋"
        if [[ -n "$command_preview" ]]; then
            echo -e "${BRIGHT_BLUE}${BOLD}Command preview: ${NC}${BOLD}${WHITE}$command_preview${NC}"
        fi

        # Auto-confirm if -y/--yes flag is set
        if [[ "$AUTO_YES" == true ]]; then
            echo -e "${BRIGHT_GREEN}${BOLD}Auto-confirming (--yes flag detected)... ${NC}✅"
            return 0  # Continue
        fi
        
        echo -e -n "\n${YELLOW}${BOLD}Do you want to continue? ${GREEN}[Y/n]: ${NC}🤔 "
        read -r confirmation
        
        if [[ -z "$confirmation" || "$confirmation" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            return 0  # Continue
        else
            echo -e "${YELLOW}${BOLD}Operation cancelled by user ${NC}🚫"
            cd "$ORIGINAL_DIR"
            return 1  # Cancel
        fi
    }

    if [[ "$RUN_ONLY" == true ]]; then
        local JAR_FILE=$(find "$BUILD_DIR" -name '*.jar' ! -name '*plain.jar' -print -quit)
        if [[ -n "$JAR_FILE" ]]; then
            local run_command="java$ENV_JVM_PROPS -Xmx128m -Xms64m -jar $JAR_FILE --spring.main.banner-mode=off --spring.profiles.active=$EFFECTIVE_SPRING_PROFILE"
            local run_desc="Run existing JAR file (profile: $EFFECTIVE_SPRING_PROFILE, no Spring banner)"
            [[ -n "$ENV_NAME" ]] && run_desc="$run_desc, env: $ENV_NAME"
            if ask_confirmation "$run_desc" "$run_command"; then
                echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${CYAN}Executing JAR file...${NC}"
                echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${WHITE}$run_command${NC}"
                eval java$ENV_JVM_PROPS -Xmx128m -Xms64m -jar "$JAR_FILE" --spring.main.banner-mode=off --spring.profiles.active="$EFFECTIVE_SPRING_PROFILE"
            fi
        else
            echo -e "${BRIGHT_RED}${BOLD}No JAR file found in ${BOLD}$BUILD_DIR${NC} ${BRIGHT_RED}${BOLD}❌${NC}"
            cd "$ORIGINAL_DIR"
            return 1
        fi
    elif [[ "$DEV_MODE" == true ]]; then
        # Run with bootRun (development mode)
        local clean_part=""
        local description=""
        local action_message=""
        
        if [[ "$NO_CLEAN" == true ]]; then
            clean_part=""
            description="Run with bootRun (profile: $EFFECTIVE_SPRING_PROFILE, no clean, no Spring banner)"
            action_message="Running with bootRun (no clean)..."
        else
            clean_part="clean "
            description="Clean and run with bootRun (profile: $EFFECTIVE_SPRING_PROFILE, no Spring banner)"
            action_message="Cleaning and running with bootRun..."
        fi
        
        local bootrun_spring_args="--spring.main.banner-mode=off --spring.profiles.active=$EFFECTIVE_SPRING_PROFILE$ENV_SPRING_ARGS"
        local bootrun_command="$GRADLE_CMD ${clean_part}bootRun --args='$bootrun_spring_args'"
        [[ -n "$ENV_NAME" ]] && description="$description, env: $ENV_NAME"
        if ask_confirmation "$description" "$bootrun_command"; then
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${GREEN}$action_message${NC}"
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${WHITE}$bootrun_command${NC}"
            eval $bootrun_command
        fi
    else
        # Detect test tasks automatically
        echo -e "\n${BRIGHT_PURPLE}${BOLD}Detecting test tasks... ${NC}🔍"
        
        # Execute detection and capture only the final result
        local TEMP_OUTPUT=$(mktemp)
        detect_test_tasks > "$TEMP_OUTPUT"
        
        # Show informative output
        cat "$TEMP_OUTPUT"
        
        # Capture only the last line containing the exclusions
        TEST_TASKS=$(tail -n 1 "$TEMP_OUTPUT")
        rm -f "$TEMP_OUTPUT"
        
        # Ask for confirmation to compile and run
        local clean_part=""
        local description=""
        local action_message=""

        if [[ "$NO_CLEAN" == true ]]; then
            clean_part=""
            description="Compile and run JAR file (profile: $EFFECTIVE_SPRING_PROFILE, skipping all test tasks, no clean)"
            action_message="Compiling with Gradle (no clean, skipping all test tasks)..."
        else
            clean_part="clean "
            description="Compile and run JAR file (profile: $EFFECTIVE_SPRING_PROFILE, skipping all test tasks)"
            action_message="Compiling with Gradle (skipping all test tasks)..."
        fi

        [[ -n "$ENV_NAME" ]] && description="$description, env: $ENV_NAME"
        local BUILD_COMMAND="$GRADLE_CMD ${clean_part}build $TEST_TASKS"
        if ask_confirmation "$description" "$BUILD_COMMAND"; then
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${GREEN}${action_message}${NC}"
            echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${CYAN}Executing:${NC} ${BOLD}${WHITE}$BUILD_COMMAND${NC}"

            eval $BUILD_COMMAND

            if [[ $? -eq 0 ]]; then
                echo -e "${BRIGHT_GREEN}${BOLD}Build successful.${NC} ${GREEN}Running JAR file... ${NC}✅"
                local JAR_FILE=$(find "$BUILD_DIR" -name '*.jar' ! -name '*plain.jar' -print -quit)
                if [[ -n "$JAR_FILE" ]]; then
                    echo -e "${BRIGHT_CYAN}${BOLD}➤${NC} ${WHITE}java$ENV_JVM_PROPS -Xmx128m -Xms64m -jar ${BOLD}${YELLOW}$JAR_FILE${NC}${WHITE} --spring.main.banner-mode=off --spring.profiles.active=$EFFECTIVE_SPRING_PROFILE${NC}"
                    eval java$ENV_JVM_PROPS -Xmx128m -Xms64m -jar "$JAR_FILE" --spring.main.banner-mode=off --spring.profiles.active="$EFFECTIVE_SPRING_PROFILE"
                else
                    echo -e "${BRIGHT_RED}${BOLD}No JAR file found in ${BOLD}$BUILD_DIR${NC} ${RED}after successful build ${NC}❌"
                    cd "$ORIGINAL_DIR"
                    return 1
                fi
            else
                echo -e "${BRIGHT_RED}${BOLD}Build failed.${NC} ${RED}Please check for errors ${NC}❌"
                cd "$ORIGINAL_DIR"
                return 1
            fi
        fi
    fi
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
}

gw() {
  if [[ -f ./gradlew ]]; then
    ./gradlew "$@"
  else
    echo "gradlew not found in this directory"
  fi
}
