#!/bin/bash

# Function to load YAML vars as UPPERCASE environment variables
yaml_to_env() {
    local yaml_file="$1"
    
    # Check if file exists
    if [[ ! -f "$yaml_file" ]]; then
        echo "Error: YAML file '$yaml_file' not found." >&2
        return 1
    fi

    # Check for Python and PyYAML
    if ! command -v python3 &> /dev/null; then
        echo "Error: Python3 is required but not installed." >&2
        return 1
    fi

    # Generate temporary file for exports
    local temp_file
    temp_file=$(mktemp) || { echo "Error: Failed to create temp file." >&2; return 1; }

    # Parse YAML and export variables (UPPERCASE keys)
    python3 -c "
import yaml, os
try:
    with open(\"$yaml_file\") as f:
        vars = yaml.safe_load(f).get(\"vars\", {})
        for k, v in vars.items():
            print(f\"export {k.upper()}=\\\"{v}\\\"\")
except Exception as e:
    print(f\"Error parsing YAML: {e}\", file=os.stderr)
    exit(1)
" > "$temp_file"

    # Check for Python errors
    if [[ $? -ne 0 ]]; then
        rm -f "$temp_file"
        return 1
    fi

    # Source the generated exports
    source "$temp_file"
    rm -f "$temp_file"

    echo "Loaded environment variables from '$yaml_file'"
}

# Example usage (uncomment to test when sourced directly)
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     yaml_to_env "$1"
# fi
    
function is_online() {
    export IS_ONLINE=$(curl -s --max-time 5 ifconfig.me >/dev/null && echo true || echo false)
}   

log_pretty() {
    # Define colors
    GREEN="\033[1;32m"
    CYAN="\033[1;36m"
    RED="\033[1;31m"
    RESET="\033[0m"
    LIGHTBLUE="\033[05;38;5;153m"
    local message="$1"
    local color
    case "$2" in
        "green")
            color=$GREEN
            ;;
        "cyan")
            color=$CYAN
            ;;
        "red")
            color=$RED
            ;;
        "lightblue")
            color=$LIGHTBLUE
            ;;
        *)
            color=$RESET
            ;;
    esac
    if [ -z "$color" ]; then
        color=$RESET
    fi
    echo -e "${color}${message}${RESET}"
}

function colorgrid( )
{
    iter=16
    while [ $iter -lt 52 ]
    do
        second=$[$iter+36]
        third=$[$second+36]
        four=$[$third+36]
        five=$[$four+36]
        six=$[$five+36]
        seven=$[$six+36]
        if [ $seven -gt 250 ];then seven=$[$seven-251]; fi

        echo -en "\033[38;5;$(echo $iter)m█ "
        printf "%03d" $iter
        echo -en "   \033[38;5;$(echo $second)m█ "
        printf "%03d" $second
        echo -en "   \033[38;5;$(echo $third)m█ "
        printf "%03d" $third
        echo -en "   \033[38;5;$(echo $four)m█ "
        printf "%03d" $four
        echo -en "   \033[38;5;$(echo $five)m█ "
        printf "%03d" $five
        echo -en "   \033[38;5;$(echo $six)m█ "
        printf "%03d" $six
        echo -en "   \033[38;5;$(echo $seven)m█ "
        printf "%03d" $seven

        iter=$[$iter+1]
        printf '\r\n'
    done
}