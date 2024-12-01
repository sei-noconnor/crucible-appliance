variable "vsphere_server" {
  type    = string
  default = ""
}

variable "vsphere_user" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type    = string
  default = ""
}

variable "datacenter" {
  type    = string
  default = ""
}

variable "cluster" {
  type    = string
  default = ""
}

variable "host" {
  type    = string
  default = ""
}

variable "datastore" {
  type    = string
  default = ""
}

variable "vsphere_template" {
  type = string
  default = "" 
}

variable "network_name" {
  type    = string
  default = ""
}

variable "ssh_username" {
  type    = string
  default = "crucible"
}

variable "ssh_password" {
  type    = string
  default = "crucible"
}

variable "appliance_version" {
  type    = string
  default = ""
}

locals {
  boot_command     = [
  "e<wait>",
  "<down><down><down>",
  "<end><bs><bs><bs><bs><wait>",
  "autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
  "<f10><wait>"
  ]
  iso_url          = "https://releases.ubuntu.com/jammy/ubuntu-22.04.4-live-server-amd64.iso"
  iso_checksum     = "sha256:45f873de9f8cb637345d6e66a583762730bbea30277ef7b32c9c3bd6700a32b2"
  shutdown_command = ""
  video_memory     = 32
}