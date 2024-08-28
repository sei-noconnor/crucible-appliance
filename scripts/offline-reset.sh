#!/bin/bash 

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

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