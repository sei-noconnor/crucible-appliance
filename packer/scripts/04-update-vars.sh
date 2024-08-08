#!/bin/bash
if [[ $# -eq 0 ]]; then

    echo "Usage: $0 <src_hcl>"
    exit 1
fi
# Load variables from YAML file (requires yq)
vars=$(yq e '.vars' vars.yaml)

# HCL file path
hcl_src=$(realpath $1)
vars_yaml=$(realpath $2)
scripts_dir=$(dirname $0)
hcl_dst=$(realpath ${hcl_src%.example})
echo "Replacing Vars in $hcl_dst from $vars_yaml using template $hcl_src"
if [ ! -f $hcl_dst ]; then
    cp $hcl_src $hcl_dst
fi

# Iterate through each variable in the YAML
for var in $(echo "$vars" | yq e '. | keys' -); do
    value=$(echo "$vars" | yq e ".$var" -)  # Extract the value

    # Replace value in HCL file using sed
    sed -i -e "s/${var} = .*/${var} = \"${value}\"/" "$hcl_dst" 
done

echo "HCL file updated successfully."