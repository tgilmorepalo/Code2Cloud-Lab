variable "vpcId" {
  type = string
}

variable "region" {
  type = string
}

variable "public_subnet_id" {
  type = list(any)
}

variable "instance_profile" {
  type = string
}

variable "vmhosts" {
  description = "List of VM hosts with their configuration"
  type = list(object({
    name           = string
    install_script = string
    instance_type  = optional(string)
    tags           = map(string)
    defender       = bool
    defender_type  = string #host or container
    private_ip     = optional(string)
    ports          = list(number)
    cidrs          = list(string)
  }))
}