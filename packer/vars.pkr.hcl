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

variable "datastore" {
  type    = string
  default = ""
}

variable "network_name" {
  type    = string
  default = ""
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ssh_password" {
  type    = string
  default = "ubuntu"
}

variable "appliance_version" {
  type    = string
  default = ""
}

locals {
  shutdown_command  = "echo '{var.ssh_password}' | sudo -S shutdown -P now"
}