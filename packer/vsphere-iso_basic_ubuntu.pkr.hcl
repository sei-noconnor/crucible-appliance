# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

packer {
  required_plugins {
    vsphere = {
      version = ">= 1.4.0"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

source "vsphere-clone" "clone" {
  ssh_username        = var.ssh_username
  ssh_password        = var.ssh_password
  ssh_timeout         ="60m"
  linked_clone        = true
  network             = var.network_name
  cluster             = var.cluster
  host                = "esx-04.covert-cloud.com"
  datastore           = "ds_nfs"
  insecure_connection = true
  password            = var.vsphere_password
  template            = var.vsphere_template
  username            = var.vsphere_user
  vcenter_server      = var.vsphere_server
  vm_name             = "crucible-appliance-argo-${var.appliance_version}"

  customize {
    linux_options {
      host_name = "crucible"
      domain = "local"
    }
    network_interface {}
  }

  export {
    output_directory = "./dist/output"
    output_format = "ovf"
  }
}

source "vsphere-iso" "iso" {
  vcenter_server      = var.vsphere_server
  username            = var.vsphere_user
  password            = var.vsphere_password
  datacenter          = var.datacenter
  cluster             = var.cluster
  host                = var.host
  insecure_connection = true

  vm_name       = "crucible-appliance-argo-${var.appliance_version}"
  guest_os_type = "ubuntu64Guest"

  CPUs            = 4
  RAM             = 4096
  RAM_reserve_all = true

  ssh_username = var.ssh_username
  ssh_password = var.ssh_password
  ssh_timeout  = "60m"
  /*
  # Uncomment when running on vcsim
  ssh_host     = "127.0.0.1"
  ssh_port     = 2222

  configuration_parameters = {
    "RUN.container" : "lscr.io/linuxserver/openssh-server:latest"
    "RUN.mountdmi" : "false"
    "RUN.port.2222" : "2222"
    "RUN.env.USER_NAME" : "crucible"
    "RUN.env.USER_PASSWORD" : "crucible"
    "RUN.env.PASSWORD_ACCESS" : "true"
  }
  */
  disk_controller_type = ["pvscsi"]
  datastore            = var.datastore
  storage {
    disk_size             = 15366
    disk_thin_provisioned = true
  }

  iso_paths = ["[iso] ubuntu-22.04-live-server-amd64.iso"]

  network_adapters {
    network = var.network_name
  }

  cd_files = ["./packer/meta-data", "./packer/user-data"]
  cd_label = "cidata"
  
  boot_command = ["<wait>e<down><down><down><end> autoinstall ds=nocloud;<F10>"]

  export {
    output_directory = "./dist/output"
    output_format = "ovf"
  }

}

build {
  sources = [
    "source.vsphere-clone.clone"
  ]

  provisioner "shell" {
    execute_command   = "echo ${var.ssh_password} | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive",
      "SSH_USERNAME=${var.ssh_username}",
      "APPLIANCE_VERSION=${var.appliance_version}"
    ]
    inline = [
      "echo \"I AM RUNNING\"",
      "sudo apt update && sudo apt install make",
      "grep -qxF 'ENVIRONMENT=APPLIANCE' '/etc/environment' || echo 'ENVIRONMENT=APPLIANCE' >> '/etc/environment'"
    ]
  }

  provisioner "shell" {
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive",
      "SSH_USERNAME=${var.ssh_username}",
    ]
    inline = [
      "mkdir /home/${var.ssh_username}/crucible-appliance-argo"
    ]
  }

  provisioner "file" {
    destination = "/home/${var.ssh_username}/crucible-appliance-argo"
    sources = [
      "./",
    ]
  }

  provisioner "shell" {
    execute_command   = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive",
      "SSH_USERNAME=${var.ssh_username}",
    ]
    inline            = [
      "cd /home/$SSH_USERNAME/crucible-appliance-argo",
      "make init"
    ]
  }

  provisioner "shell" {
    execute_command   = "echo '${var.ssh_password}' | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive",
      "SSH_USERNAME=${var.ssh_username}",
    ]
    inline = [
      "cd /home/$SSH_USERNAME/crucible-appliance-argo",
      "make snapshot"
    ]
  }

  provisioner "shell" {
    execute_command   = "echo ${var.ssh_password} | {{ .Vars }} sudo -E -S bash '{{ .Path }}'"
    environment_vars  = [
      "DEBIAN_FRONTEND=noninteractive",
      "SSH_USERNAME=${var.ssh_username}",
      "APPLIANCE_VERSION=${var.appliance_version}"
    ]
    inline = [
      "cd /home/$SSH_USERNAME/crucible-appliance-argo",
      "make shrink"
    ]
  }
  
  provisioner "shell-local" {
    inline = ["echo the address is: $PACKER_HTTP_ADDR and build name is: $PACKER_BUILD_NAME"]
  }
}