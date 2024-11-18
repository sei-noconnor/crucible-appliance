#!/bin/bash 

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
declare -i i
for f in "${files[@]}"; do
    #get epoch 
    i+=1
    epoch=${f##*\-}
    f="$i) $f ($(TZ=America/New_York date -d @$epoch))"
done

echo "Matching files:"
select filename in "${files[@]}"
do
    if [ -n "$filename" ]; then
        echo "You selected: $filename"
        sudo systemctl stop k3s
        sudo k3s server --cluster-reset --cluster-reset-restore-path=$filename
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
--for=condition=Avaialble \
--all-namespaces=true \
--timeout=1m