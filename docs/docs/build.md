# Building and Deploying the Crucible Appliance

The Crucible Appliance is a comprehensive virtual machine solution designed for seamless deployment and operation in vSphere environments. This document provides detailed instructions for building and deploying the appliance as an OVA (Open Virtual Appliance) file.

## Building an OVA

The Crucible Appliance leverages Packer scripts to automate the creation process, producing an OVA that can be imported into vSphere environments. The build process involves several key components that prepare the system, configure dependencies, and package everything into a deployable format.

### Building the Appliance

The Crucible Appliance is tested on vSphere 8, ensuring seamless compatibility and optimal performance. To build the appliance from source, follow these steps:

1. **Copy the Variable File:**

```bash
cp appliance.example.yaml appliance.yaml
```

2. **Customize Your Environment:**

Modify the `appliance.yaml` file to match your environment. This includes setting the vSphere server, user credentials, datacenter, cluster, datastore, and network details. Ensure these settings match your vSphere configuration to avoid deployment errors.

```yaml
vars:
  vsphere_server: vcsa.example.com
  vsphere_user: administrator@vsphere.local
  vsphere_password: pasword1234!@
  datacenter: Datacenter1
  cluster: Cluster1
  datastore: ds1
  network_name: "VM Network"
  ssh_username: crucible
  ssh_password: crucible
```

3. **Run the Build Process:**

The build process utilizes several scripts to create the appliance. Execute the following command to start the build:

```bash
make build
```

This command performs several key tasks[^1]:
    - Cleans previous build outputs
    - Updates build variables from your `appliance.yaml`
    - Runs the main build script to create the appliance image
4. **Package the OVA:**

After the build completes, package the appliance as an OVA file for deployment:

```bash
make package-ova
```

This command runs the `package-ova.sh` script that packages the appliance as an Open Virtual Appliance file ready for deployment to virtualization platforms[^1].
5. **Optional: Shrink the Disk Image:**

If you need to reduce the size of the appliance for distribution, you can run:

```bash
make shrink
```

This executes the `shrink.sh` script that reduces the appliance disk image size[^1].

## Deploying an OVA

Once you have built or obtained the Crucible Appliance OVA, you can deploy it to your vSphere environment using the following steps:

1. **Get the OVA File:**
Obtain the OVA file either from your build process or from the GitHub releases page.
2. **Deploy via vSphere Web UI:**
    - In the vSphere Web UI, right-click on the cluster where you want to deploy the appliance and select "Deploy OVF Template"
    - Provide the OVA file location (either local file or URL)
    - Validate the source if prompted
    - Fill in the VM details, selecting the appropriate storage and networking options
    - Click "Finish" to deploy the template
3. **Increase Storage Before Power On:**
Before powering on the VM, increase the storage capacity of the main disk:
    - Right-click the appliance VM and select "Edit Settings"
    - Increase the main hard disk to one terabyte (1TB)
4. **Post-Deployment Initialization:**
After powering on the VM, the appliance will automatically run through several initialization steps:
    - Certificate generation for internal and external trust[^1]
    - OS-level configuration and dependency installation[^1]
    - Host entry configuration for proper domain resolution[^1]
    - ArgoCD and related services initialization[^1]
    - Vault unsealing and configuration[^1]
    - Gitea service setup for internal Git operations[^1]
5. **Verify Deployment:**
    - Check the startup logs to monitor the initialization process:

```bash
make startup-logs
```

    - Or follow the logs in real-time:

```bash
make startup-tail-logs
```


## Troubleshooting and Maintenance

The Crucible Appliance includes several utilities for troubleshooting and maintenance:

1. **Reset Options:**
    - For a full reset: `make reset`
    - For an offline reset: `make offline-reset`
2. **Certificate Management:**
    - Clean certificates: `make clean-certs`
    - Generate new certificates: `make generatecerts`
3. **Snapshot Management:**
    - Create snapshots: `make snapshot`
    - This enables rollback to a known good state if needed[^1]
4. **Uninstallation:**
    - To completely remove the appliance: `make uninstall`
    - This scales down and deletes all Crucible-related Kubernetes deployments, cleans up storage, and resets root certificates[^1]

By following these build and deployment instructions, you should have a fully functional Crucible Appliance running in your vSphere environment.

## Conclusion

The Crucible Appliance build and deployment process is designed to be straightforward while providing flexibility for different environments. The use of automated scripts simplifies both the creation and deployment processes, ensuring consistency and reliability. After deployment, the appliance is ready for configuration and use, with various management commands available for ongoing maintenance and troubleshooting.