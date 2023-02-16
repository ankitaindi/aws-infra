variable "provider_region" {
  description = "Region for Provider"
  type        = string
  default     = "us-east-1"
}

variable "provider_profile" {
  description = "Profile for Provider"
  type        = string
  default     = "dev"
}

variable "vpc_cidr_block" {
  description = "CIDR for vpc infra"
  type        = string
  default     = "10.1.0.0/16"
}

variable "vpc_enable_dns_hostnames" {
  description = "Enable DNS Hostname for vpc"
  type        = bool
  default     = true
}

variable "vpc_enable_dns_support" {
  description = "Enable DNS Support for vpc"
  type        = bool
  default     = true
}

variable "vpc_assign_generated_ipv6_cidr_block" {
  description = "Assign Generated IPv6 Cidr block"
  type        = bool
  default     = true
}

variable "vpc_display_name" {
  description = "Vpc name displayed in console"
  type        = string
  default     = "vpc_infra_1"
}

variable "infra_display_name" {
  description = "Internet gateway name displayed in console"
  type        = string
  default     = "infra_gw"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "route_display_name" {
  description = "Route table display name"
  type        = string
  default     = "public_route"
}



