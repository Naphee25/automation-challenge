variable "name" {
    type = string
    description = "name"
    default = "Nafisah001"
}


variable "location1" {
    type = string
    description = "VM Location"
    default = "westeurope"
}


variable "scfile" {
  type = string
  default = "/scripts/init.sh"
}