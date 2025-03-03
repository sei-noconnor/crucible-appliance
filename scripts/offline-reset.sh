#!/bin/bash 

# Default values
DIRECTORY="/var/lib/rancher/k3s/server/db/snapshots"
PREFIX="*"
TIME=15
SORT_ORDER="newest"

# Usage function
usage() {
    echo "Usage: $0 [-d|--directory <directory>] [-p|--prefix <prefix>] [-t|--time <time>] [-s|--sort <newest|oldest>] [-h|--help]"
    echo "  -d, --directory    Set the directory to search for snapshots (default: /var/lib/rancher/k3s/server/db/snapshots)"
    echo "  -p, --prefix       Set the prefix to search for snapshots (default: *)"
    echo "  -t, --time         Set the sleep time after reset (default: 15)"
    echo "  -s, --sort         Set the sort order (newest or oldest, default: newest)"
    echo "  -h, --help         Display this help message"
    echo ""
    echo "Example: $0 -d /custom/directory -p custom-prefix -t 20 -s newest"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--directory) DIRECTORY="$2"; shift ;;
        -p|--prefix) PREFIX="$2"; shift ;;
        -t|--time) TIME="$2"; shift ;;
        -s|--sort) SORT_ORDER="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

trap 'kubectl scale deployment --all -n gitea --replicas=1; kubectl scale deployment --all -n argocd --replicas=1; kubectl scale statefulsets --all -n argocd --replicas=1; kubectl scale statefulsets --all -n postgres --replicas=1; kubectl scale statefulsets --all -n vault --replicas=1' EXIT

kubectl scale deployment --all -n gitea --replicas=0
kubectl scale deployment --all -n argocd --replicas=0
kubectl scale statefulsets --all -n argocd --replicas=0
kubectl scale statefulsets --all -n postgres --replicas=0
kubectl scale statefulsets --all -n vault --replicas=0

files=($(find "$DIRECTORY" -type f -name "*$PREFIX*" -print))

if [ "$SORT_ORDER" = "newest" ]; then
    files=($(ls -t "${files[@]}"))
else
    files=($(ls -tr "${files[@]}"))
fi

if [ ${#files[@]} -eq 0 ]; then
    echo "No file found with the prefix '$PREFIX' in '$DIRECTORY'."
    exit 1
fi

i=1
formatted_files=()
actual_files=()

for f in "${files[@]}"; do
    epoch=${f##*-}
    epoch=${epoch%.zip}
    str_date=$(TZ=America/New_York date -d @$epoch +"%Y-%m-%d %H:%M:%S")
    formatted_files+=("$(printf "\e[32m%-3d\e[0m \e[34m%-55s\e[0m \e[33m%-20s\e[0m" $i "$(basename "$f")" "$str_date")")
    actual_files+=("$f")
    ((i++))
done

echo -e "Matching files:"
printf "\e[32m%-3s\e[0m \e[34m%-55s\e[0m \e[33m%-20s\e[0m\n" "No." "File" "Date"
printf "\e[32m%-3s\e[0m \e[34m%-55s\e[0m \e[33m%-20s\e[0m\n" "---" "---------------------------------------------------" "-------------------"
for file in "${formatted_files[@]}"; do
    echo -e "$file"
done

echo -e "Select a file by number:"
read -r selection </dev/tty

if [[ $selection -gt 0 && $selection -le ${#formatted_files[@]} ]]; then
    index=$((selection - 1))
    selected_file="${actual_files[$index]}"
    echo "You selected: $selected_file"
    sudo systemctl stop k3s
    sudo k3s server --cluster-reset --cluster-reset-restore-path=$selected_file
    sudo systemctl daemon-reload
    sudo systemctl start k3s
else
    echo "Invalid selection. Exiting."
    exit 1
fi

echo "CLUSTER RESET!"
echo "Sleeping for $TIME"
sleep $TIME
echo "Waiting for Cluster deployments 'Status: Available'. This may cause a timeout."
kubectl wait deployment \
--all \
--for=condition=Available \
--all-namespaces=true \
--timeout=30s
rm ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-role-id
rm ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-secret-id
