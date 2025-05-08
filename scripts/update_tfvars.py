#!/usr/bin/env python3
import yaml
import re
import os  # Added to handle environment variables

# File paths
yaml_file = "/home/ubuntu/work/crucible-appliance/appliance.yaml"
tfvars_template = "/home/ubuntu/work/crucible-appliance/terraform/variables.auto.tfvars.tpl"
tfvars_output = "/home/ubuntu/work/crucible-appliance/terraform/variables.auto.tfvars"

# Load appliance.yaml
with open(yaml_file, "r") as file:
    data = yaml.safe_load(file)

# Extract variables
vars_section = data.get("vars", {})
cluster_section = data.get("cluster", {})

# Read the template file
with open(tfvars_template, "r") as file:
    tfvars_content = file.read()

# Replace placeholders in the template
for key, value in vars_section.items():
    placeholder = f"${{{key.upper()}}}"
    if isinstance(value, str):
        tfvars_content = tfvars_content.replace(placeholder, value)
    elif isinstance(value, list):
        tfvars_content = tfvars_content.replace(placeholder, str(value))

# Replace environment variable placeholders
env_placeholders = re.findall(r"\$\{([A-Z0-9_]+)\}", tfvars_content)
for env_var in env_placeholders:
    env_value = os.getenv(env_var, "")
    tfvars_content = tfvars_content.replace(f"${{{env_var}}}", env_value)

# Translate the cluster section to the vms section
vms_section = "vms = {\n"
for vm_name, vm_config in cluster_section.items():
    ip = f"{vars_section.get('default_network', '').rsplit('.', 1)[0]}.{vm_config['ip']}"
    vms_section += f"  {vm_name} = {{\n"
    vms_section += f"    ip     = \"{ip}\"\n"
    vms_section += f"    cpus   = {vm_config['cpus']}\n"
    vms_section += f"    memory = {vm_config['memory']}\n"
    vms_section += f"    extra_config = {vm_config.get('extra_config', {})}\n"
    vms_section += f"  }},\n"
vms_section += "}\n"

# Replace the vms section in the template (overwrite it entirely)
tfvars_content = re.sub(r"vms\s*=\s*\{.*?\}\s*", vms_section, tfvars_content, flags=re.DOTALL)

# Write the updated content to the output file
with open(tfvars_output, "w") as file:
    file.write(tfvars_content)

print(f"Updated Terraform variables file written to {tfvars_output}")