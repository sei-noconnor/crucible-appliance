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
    
