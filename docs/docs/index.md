# Crucible Appliance Documentation

## Overview

The Crucible Appliance is a self-contained virtual machine that delivers the Crucible suite of workforce development applications from the Software Engineering Institute at Carnegie Mellon University. It provides platforms for cyber training, scenario delivery, lab management, and supporting services like version control, identity management, and orchestration.

### Core Features

* Unified user authentication via Keycloak
* Secure credential and config management with Vault
* Deployed on vSphere as an OVA
* K3s-based Kubernetes cluster
* Automated configuration with Makefile scripts
* Distributed storage system with longhorn. 

## Getting Started

To begin using the Crucible Appliance, follow these steps to install the root certificate. This certificate ensures secure HTTPS access to all the appliance's web services. This step cannot be skipped you __must__ install the root certificate or the application api calls will fail you cannot accept the exception in the browser

### Step 1: Download Root Certificate

* Download Crucible Root Certificate <button onclick="downloadCert()">Download root-ca.crt</button>

### Step 2: Install Certificate

#### Windows

1. Double-click the downloaded `root-ca.crt` file.
2. Click "Install Certificate".
3. Choose "Local Machine" and click "Next".
4. Select "Place all certificates in the following store" and choose "Trusted Root Certification Authorities".
5. Click "Next" and then "Finish".
6. Restart your browser.

#### macOS

1. Double-click the `root.crt` file.
2. Keychain Access will open. Select the "System" keychain.
3. Drag the certificate into the "System" keychain.
4. Right-click the certificate, select "Get Info", and set "When using this certificate" to "Always Trust".
5. Close the dialog and enter your password if prompted.
6. Restart your browser.

#### Linux

1. Copy `root.crt` to `/usr/local/share/ca-certificates/` (rename to `crucible-root.crt` if desired).
2. Run:

   ```bash
   sudo cp root.crt /usr/local/share/ca-certificates/crucible-root.crt
   sudo update-ca-certificates
   ```
3. Restart your browser or relevant services.

---
