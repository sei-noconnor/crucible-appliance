#!/bin/bash
# This script manages entries in the /etc/hosts file.
# It supports adding (upserting) and deleting entries based on the provided IP address and records.
#
# Usage:
#   ./add-hosts-entry.sh [-f|--hosts_file <hosts_file>] [-r|--records <record1,record2,...>] [-a|--action <action>] [-h|--help]
#
# Options:
#   -f, --hosts_file       Set the hosts file (default: /etc/hosts)
#   -r, --records          Set the records (comma-separated, default: crucible.io)
#   -a, --action           Set the action (upsert, delete) (default: upsert)
#   -h, --help             Display this help message
#
# Example:
#   ./add-hosts-entry.sh -f /etc/hosts -r example.com,example.org -a upsert
#
# The script determines the IP address of the current machine and performs the specified action (upsert or delete)
# on the provided records in the specified hosts file.
#
# Actions:
#   upsert - Adds or updates the entry for the given record(s) with the current machine's IP address.
#   delete - Removes the entry for the given record(s) with the current machine's IP address.
#
# Debug messages are printed to indicate the actions being performed.
# The updated hosts file is displayed at the end of the script execution.


# Default values
HOSTS_FILE="/etc/hosts"
RECORDS=("crucible.io")
ACTION="upsert"

# Usage function
usage() {
    echo "Usage: $0 [-f|--hosts_file <hosts_file>] [-r|--records <record1,record2,...>] [-a|--action <action>] [-h|--help]"
    echo "  -f, --hosts_file       Set the hosts file (default: /etc/hosts)"
    echo "  -r, --records          Set the records (comma-separated, default: crucible.io)"
    echo "  -a, --action           Set the action (upsert, delete) (default: upsert)"
    echo "  -h, --help             Display this help message"
    echo ""
    echo "Example: $0 -f /etc/hosts -r example.com,example.org -a upsert"
    exit 1
}

# Parse options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -f|--hosts_file) HOSTS_FILE="$2"; shift ;;
        -r|--records) IFS=',' read -r -a RECORDS <<< "$2"; shift ;;
        -a|--action) ACTION="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

IP=$(ip route get 1 | awk '{print $(NF-2);exit}')

export IP=$IP

# Perform the specified action only on the hosts file
for RECORD in "${RECORDS[@]}"; do
    case $ACTION in
        upsert)
            if grep -q "$IP $RECORD" "$HOSTS_FILE"; then
                echo "Debug: Entry for $RECORD already exists, updating."
                sudo sed -i "s/.* $RECORD/$IP $RECORD/" "$HOSTS_FILE"
            else
                echo "Debug: Adding new entry for $RECORD."
                echo "$IP $RECORD" | sudo tee -a "$HOSTS_FILE" > /dev/null
            fi
            ;;
        delete)
            if grep -q "$IP $RECORD" "$HOSTS_FILE"; then
                echo "Debug: Deleting entry for $RECORD."
                sudo sed -i "/$IP $RECORD/d" "$HOSTS_FILE"
            else
                echo "Debug: Entry for $RECORD does not exist."
            fi
            ;;
        *)
            echo "Unknown action: $ACTION"
            usage
            ;;
    esac
done

# Display the updated hosts file
cat "$HOSTS_FILE"
echo "Debug: Updated hosts file $HOSTS_FILE"

