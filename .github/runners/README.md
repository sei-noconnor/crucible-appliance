## Self Hosted Runner for building the appliance
To address the limitations and costs associated with GitHub-hosted runners, the Crucible appliance includes a set of scripts designed to deploy self-hosted runners. These runners allow you to utilize your own local resources, such as vCenter servers, network storage, and other infrastructure components, to provision virtual machine (VM) images for the appliance through GitHub Actions. This setup offers greater control and flexibility by leveraging your existing environment, reducing reliance on external, paid runners, and enabling more efficient use of your local resources for VM provisioning.

### Required
___
1.  **Copy the Variable File:**

    ```bash
      `cp appliance.yaml.example appliance.yaml`
    ```


2.  **Customize Your Environment:**

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

3.  **Deploy the runner**

    ```bash
    make deploy-runner
    ```



### Configure the Runnner
the start script will create a kind cluster and deploy a kubernetes self-hosted runner to the cluster. You can optionally run this in an existing cluster


```
export GITHUB_PERSONAL_TOKEN=<your token>
# Run this from repo root 
make deploy-runner
```