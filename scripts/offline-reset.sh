#!/bin/bash -x 

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi
kubectl scale deployment --all -n gitea --replicas=0
kubectl scale deployment --all -n argocd --replicas=0
kubectl scale statefulsets --all -n argocd --replicas=0
kubectl scale statefulsets --all -n postgres --replicas=0
kubectl scale statefulsets --all -n vault --replicas=0

directory="/var/lib/rancher/k3s/server/db/snapshots"
prefix=${1:-\*}

files=($(find "$directory" -type f -name "*$prefix*" -print))

if [ ${#files[@]} -eq 0 ]; then
    echo "No file found with the prefix '$prefix' in '$directory'."
    exit 1
fi

i=1
formatted_files=()
actual_files=()

for f in "${files[@]}"; do
    #get epoch 
    epoch=${f##*-}
    epoch=${epoch%.zip}
    str_date=$(TZ=America/New_York date -d @$epoch)
    formatted_files+=(" $(basename "$f") ($str_date)")
    actual_files+=("$f")
    ((i++))
done

echo "Matching files:"
select filename in "${formatted_files[@]}"
do
    if [ -n "$filename" ]; then
        index=$((REPLY - 1))
        selected_file="${actual_files[$index]}"
        echo "You selected: $selected_file"
        sudo systemctl stop k3s
        sudo k3s server --cluster-reset --cluster-reset-restore-path=$selected_file
        sudo systemctl daemon-reload
        sudo systemctl start k3s
        break;
    else
        echo "Invalid selection. Please try again."
    fi
done </dev/tty
echo "CLUSTER RESET!"
time=15
echo "Sleeping for $time"
sleep $time
echo "Waiting for Cluster deployments 'Status: Avaialble' This may cause a timeout."
kubectl wait deployment \
--all \
--for=condition=Available \
--all-namespaces=true \
--timeout=30s
rm ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-role-id
rm ./argocd/install/argocd/kustomize/overlays/appliance/files/argo-secret-id