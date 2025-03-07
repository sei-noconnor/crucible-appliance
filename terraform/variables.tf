variable "vsphere_server" {}
variable "vsphere_user" {}
variable "vsphere_pass" {}
variable "datacenter" {}
variable "cluster" {}
variable "dvswitch" {}
variable "vsphere_datastore" {}
variable "iso_datastore" {}
variable "template" {}
variable "sudo_username" {
  default = "crucible"
}
variable "sudo_password" {
  default = "crucible"
}
variable "folder" {
  default = ""
}
variable "view_id" {
  default = "unique"
}
variable "admin" {
  default = "07704bcb-91d6-42aa-bb26-3046e9cc4cb6"
}
variable "blue" {
  default = "05d43d63-f726-4df2-9bb4-5b9a8d6eecab"
}
variable "domain" {
  type = string
}
variable "default_portgroup" {
  default = "portgroup"
}
variable "default_netmask" {
  default = "24"
}
variable "default_gateway" {
  default = "192.168.1.1"
}
variable "dns_servers" {
  type = list(string)
}
variable "vms" {
  type = map(object({
    ip     = string
    cpus   = number
    memory = number
    extra_config = map(string)
  }))

  default = {
    extra_config = null
  }
}
