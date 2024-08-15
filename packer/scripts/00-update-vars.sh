#!/bin/bash
if [[ $# -eq 0 ]]; then

    echo "Usage: $0 <src_vars_yaml>"
    exit 1
fi

# HCL file path
vars_yaml=$(realpath $1)
hcl_src=$(realpath packer/vars.auto.pkrvars.hcl.example)

scripts_dir=$(dirname $0)
echo "scripts_dir: $scripts_dir"
echo "Intended out: ${hcl_src%.example}"
hcl_dst="${hcl_src%\.example}"
if [ ! -f $hcl_dst ]; then
    echo "Destination file does NOT exists, creating..."
    cp $hcl_src $hcl_dst
else
    # Clobber anyway
    echo "Destination file does EXISTS, overwritting..."
    cp $hcl_src $hcl_dst
fi

# Load variables from YAML file (requires yq)
vars=$(yq e '.vars' $vars_yaml)

echo "Replacing Vars in $hcl_dst from $vars_yaml using template $hcl_src"
# Iterate through each variable in the YAML
for var in $(echo "$vars" | yq e '. | keys' -); do
    value=$(echo "$vars" | yq e ".$var" -)  # Extract the value

    # Replace value in HCL file using sed
    sed -i -e "s/${var} = .*/${var} = \"${value}\"/" "$hcl_dst" 
done
rm $(dirname $hcl_dst)/vars.auto.pkrvars.hcl-e
echo "HCL file updated successfully."