# vSphere deployment

1. Get the OVA URL from the GitHub [releases page](), You can import this directly into vCenter
1. In the vShpere, Web UI right click on the cluster you want to deploy the appliance too and click "Deploy OVF Template".
1. Paste the URL in the field provided and click "Next"
1. Validate the source, if asked
1. Fill in the VM details, Selecting the correct storage and networking
1. Click "Finish"

Before powering on the VM, we're going to want to increase the storage of the main disk. 

1. Right, click the appliance VM and select "edit settings"
1. Increase the main hard disk to one terrabyte (TB)

