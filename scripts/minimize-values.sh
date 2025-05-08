# This script minimizes Helm chart values by comparing custom values files with default values
# and merges the minimal differences into a main configuration file.

# Configuration:
# - CHART_DIR: Directory containing Helm chart archives (.tgz).
# - MAIN_VALUES_FILE: Path to the main values.yaml file to be updated.
# - MANIFEST_DIRS: Array of directories to search for custom values files.

# Workflow:
# 1. Creates a temporary directory for intermediate files.
# 2. Iterates through all Helm chart archives in CHART_DIR.
# 3. Skips the "crucible" chart to avoid processing its values.
# 4. Extracts default values for each chart using `helm show values`.
# 5. Searches for custom values files in the specified MANIFEST_DIRS.
# 6. Handles multiple custom values files by prompting the user to select one.
# 7. Compares the custom values file with the default values:
#    - Retains only the differences (minimal values).
#    - Removes commented lines from the minimal values.
# 8. Merges the minimal values into the MAIN_VALUES_FILE under the chart's name.
# 9. Cleans up the temporary directory upon script exit.

# Dependencies:
# - `helm`: Used to extract default values from chart archives.
# - `yq`: Used for YAML processing and merging values.
# - `sed`: Used to remove commented lines from the minimal values.

# Notes:
# - The script updates the MAIN_VALUES_FILE in place. IT CLOBBERS THE EXISTING FILE.
# - If no custom values file is found for a chart, it is skipped.
# - If no differences are found between the custom and default values, the chart is skipped.


# Output:
# - Updates the MAIN_VALUES_FILE with minimal values for each processed chart.
# - Logs the processing steps and any skipped charts or files.
#!/bin/bash

# Configuration
CHART_DIR="./argocd/local-charts/crucible/charts"
MAIN_VALUES_FILE="./argocd/local-charts/crucible/values.yaml"
MANIFEST_DIRS=(
  "./argocd/apps/prod-argo"
  "./argocd/apps/prod-k8s"
  "./argocd/install"
)

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Iterate through charts
find "$CHART_DIR" -maxdepth 1 -name '*.tgz' -print0 | while IFS= read -r -d '' chart_path; do
  # Extract chart name
  chart_file="$(basename $chart_path)"
  chart_name_version="${chart_file%.tgz}"
  chart_name="${chart_name_version%-*}"

  # Skip crucible chart
  [[ "$chart_name" == "crucible" ]] && continue

  echo -e "\nProcessing chart: $chart_name"

  # Generate default values
  helm show values "$chart_path" > "$TMP_DIR/$chart_name-default.yaml"

  # Find existing values files
  declare -a values_files=()
  
  for dir in "${MANIFEST_DIRS[@]}"; do
    while IFS= read -r -d '' file; do
      values_files+=("$file")
    done < <(find "$dir" -type f -iname "*$chart_name*values*yaml" -print0)
  done

  # Handle multiple values files
  if [[ ${#values_files[@]} -gt 1 ]]; then
    echo "Multiple values files found:"
    select values_file in "${values_files[@]}" "Skip"; do
      [[ "$values_file" == "Skip" ]] && continue 2
      [[ -n "$values_file" ]] && break
    done
  elif [[ ${#values_files[@]} -eq 1 ]]; then
    values_file="${values_files[0]}"
  else
    echo "No values.yaml found for $chart_name, skipping..."
    continue
  fi

  echo "Using values file: $values_file"

  # Generate minimal values
  yq eval-all '
    select(fileIndex == 1) as $custom |
    select(fileIndex == 0) as $default |
    $custom | 
    (.. | select(tag == "!!map")) |= with(.; 
      to_entries | map(select(
        (.value != $default[.key]) or ($default[.key] | not)
      )) | from_entries
    )
  ' "$TMP_DIR/$chart_name-default.yaml" "$values_file" > "$TMP_DIR/$chart_name-minimal.yaml"
  
# Merge into main values file
  if [[ -f "$TMP_DIR/$chart_name-minimal.yaml" && -s "$TMP_DIR/$chart_name-minimal.yaml" ]]; then
    # Remove commented lines from minimal values
    sed -i '/^\s*#/d' "$TMP_DIR/$chart_name-minimal.yaml"
    echo "Adding minimal values to main configuration"
    yq eval ".$chart_name = load(\"$TMP_DIR/$chart_name-minimal.yaml\")" "$MAIN_VALUES_FILE" -i
  else
    echo "No differences found from default values, skipping merge"
  fi
done

echo -e "\nProcessing complete. Main values file updated at: $MAIN_VALUES_FILE"

