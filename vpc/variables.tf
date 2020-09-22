
variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "vpc_name" {
  description = "Name to be used on the VPC"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "0.0.0.0/0"
}

variable "vpc_environment_code" {
  description = "An abbreviation of a logical environment (e.g. dce)"
  type        = string
  default     = ""
}

variable "vpc_enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = false
}

variable "vpc_enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "vpc_create_internet_gateway" {
  description = "Controls if an internet gateway should be created"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = false
}

variable "region_code" {
  description = "The abbreviation of the region"
  type        = string
  default     = ""
}

variable "region_code_long" {
  description = "The name of the region"
  type        = string
  default     = ""
}

variable "azs" {
  description = "A list of availability zone names in the region"
  type        = list(string)
  default     = []
}

variable "azs_code" {
  description = "A list of availability zone code names in the region"
  type        = list(string)
  default     = []
}

variable "public_subnet_suffix" {
  description = "Suffix to append to public subnets name"
  type        = string
  default     = "public"
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  type        = map(string)
  default     = {}
}

variable "frontend_subnet_suffix" {
  description = "Suffix to append to frontend subnets name"
  type        = string
  default     = "frontend"
}

variable "frontend_subnets" {
  description = "A list of frontend subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "frontend_subnet_tags" {
  description = "Additional tags for the frontend subnets"
  type        = map(string)
  default     = {}
}

variable "app_subnet_suffix" {
  description = "Suffix to append to app subnets name"
  type        = string
  default     = "app"
}

variable "app_subnets" {
  description = "A list of application subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "app_subnet_tags" {
  description = "Additional tags for the application subnets"
  type        = map(string)
  default     = {}
}

variable "create_app_subnet_route_table" {
  description = "Controls if separate route table for application subnet should be created"
  type        = bool
  default     = true
}

variable "db_subnet_suffix" {
  description = "Suffix to append to database subnets name"
  type        = string
  default     = "db"
}

variable "db_subnets" {
  description = "A list of database subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "create_database_subnet_group" {
  description = "Controls if database subnet group should be created (n.b. db_subnets must also be set)"
  type        = bool
  default     = true
}

variable "database_subnet_group_tags" {
  description = "Additional tags for the database subnet group"
  type        = map(string)
  default     = {}
}

variable "db_subnet_tags" {
  description = "Additional tags for the db subnets"
  type        = map(string)
  default     = {}
}

variable "create_db_subnet_route_table" {
  description = "Controls if separate route table for database subnet should be created"
  type        = bool
  default     = true
}

variable "internal_subnet_suffix" {
  description = "Suffix to append to internal subnets name"
  type        = string
  default     = "internal"
}

variable "internal_subnets" {
  description = "A list of internal subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "internal_subnet_tags" {
  description = "Additional tags for the internal subnets"
  type        = map(string)
  default     = {}
}

variable "create_internal_subnet_route_table" {
  description = "Controls if separate route table for internal subnet should be created"
  type        = bool
  default     = true
}

variable "ecs_subnet_suffix" {
  description = "Suffix to append to ECS subnets name"
  type        = string
  default     = "ecs"
}

variable "ecs_subnets" {
  description = "A list of ECS subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "ecs_subnet_tags" {
  description = "Additional tags for the ECS subnets"
  type        = map(string)
  default     = {}
}

variable "create_ecs_subnet_route_table" {
  description = "Controls if separate route table for ECS subnet should be created"
  type        = bool
  default     = true
}

variable "eks_subnet_suffix" {
  description = "Suffix to append to EKS subnets name"
  type        = string
  default     = "eks"
}

variable "eks_subnets" {
  description = "A list of EKS subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "eks_subnet_tags" {
  description = "Additional tags for the EKS subnets"
  type        = map(string)
  default     = {}
}

variable "create_eks_subnet_route_table" {
  description = "Controls if separate route table for EKS subnet should be created"
  type        = bool
  default     = true
}

variable "ocp3_subnet_suffix" {
  description = "Suffix to append to OpenShift3 subnets name"
  type        = string
  default     = "ocp3"
}

variable "ocp3_subnets" {
  description = "A list of OpenShift3 subnets inside the VPC"
  type        = list(string)
  default     = []
}

variable "ocp3_subnet_tags" {
  description = "Additional tags for the OpenShift3 subnets"
  type        = map(string)
  default     = {}
}

variable "create_ocp3_subnet_route_table" {
  description = "Controls if separate route table for OpenShift3 subnet should be created"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone. Requires `var.azs` to be set, and the number of `public_subnets` created to be greater than or equal to the number of availability zones specified in `var.azs`."
  type        = bool
  default     = false
}

variable "vpc_endpoint_tags" {
  description = "Additional tags for the VPC Endpoints"
  type        = map(string)
  default     = {}
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"
}

variable "enable_classiclink" {
  description = "Should be true to enable ClassicLink for the VPC. Only valid in regions and accounts that support EC2 Classic."
  type        = bool
  default     = null
}

variable "enable_classiclink_dns_support" {
  description = "Should be true to enable ClassicLink DNS Support for the VPC. Only valid in regions and accounts that support EC2 Classic."
  type        = bool
  default     = null
}

variable "enable_ipv6" {
  description = "Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block."
  type        = bool
  default     = false
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  type        = map(string)
  default     = {}
}

variable "secondary_cidr_blocks" {
  description = "List of secondary CIDR blocks to associate with the VPC to extend the IP Address pool"
  type        = list(string)
  default     = []
}

variable "enable_dhcp_options" {
  description = "Should be true if you want to specify a DHCP options set with a custom domain name, DNS servers, NTP servers, netbios servers, and/or netbios server type"
  type        = bool
  default     = false
}

variable "dhcp_options_domain_name" {
  description = "Specifies DNS name for DHCP options set (requires enable_dhcp_options set to true)"
  type        = string
  default     = ""
}

variable "dhcp_options_domain_name_servers" {
  description = "Specify a list of DNS server addresses for DHCP options set, default to AWS provided (requires enable_dhcp_options set to true)"
  type        = list(string)
  default     = ["AmazonProvidedDNS"]
}

variable "dhcp_options_ntp_servers" {
  description = "Specify a list of NTP servers for DHCP options set (requires enable_dhcp_options set to true)"
  type        = list(string)
  default     = []
}

variable "dhcp_options_netbios_name_servers" {
  description = "Specify a list of netbios servers for DHCP options set (requires enable_dhcp_options set to true)"
  type        = list(string)
  default     = []
}

variable "dhcp_options_netbios_node_type" {
  description = "Specify netbios node_type for DHCP options set (requires enable_dhcp_options set to true)"
  type        = string
  default     = ""
}

variable "dhcp_options_tags" {
  description = "Additional tags for the DHCP option set (requires enable_dhcp_options set to true)"
  type        = map(string)
  default     = {}
}

variable "igw_tags" {
  description = "Additional tags for the internet gateway"
  type        = map(string)
  default     = {}
}

variable "reuse_nat_ips" {
  description = "Should be true if you don't want EIPs to be created for your NAT Gateways and will instead pass them in via the 'external_nat_ip_ids' variable"
  type        = bool
  default     = false
}

variable "nat_eip_tags" {
  description = "Additional tags for the NAT EIP"
  type        = map(string)
  default     = {}
}

variable "external_nat_ip_ids" {
  description = "List of EIP IDs to be assigned to the NAT Gateways (used in combination with reuse_nat_ips)"
  type        = list(string)
  default     = []
}

variable "external_nat_ips" {
  description = "List of EIPs to be used for `nat_public_ips` output (used in combination with reuse_nat_ips and external_nat_ip_ids)"
  type        = list(string)
  default     = []
}

variable "nat_gateway_tags" {
  description = "Additional tags for the NAT gateways"
  type        = map(string)
  default     = {}
}

variable "public_route_table_tags" {
  description = "Additional tags for the route tables"
  type        = map(string)
  default     = {}
}

variable "frontend_route_table_tags" {
  description = "Additional tags for the route tables"
  type        = map(string)
  default     = {}
}

variable "app_route_table_tags" {
  description = "Additional tags for the application route tables"
  type        = map(string)
  default     = {}
}

variable "db_route_table_tags" {
  description = "Additional tags for the database route tables"
  type        = map(string)
  default     = {}
}

variable "internal_route_table_tags" {
  description = "Additional tags for the internal route tables"
  type        = map(string)
  default     = {}
}

variable "ecs_route_table_tags" {
  description = "Additional tags for the ECS route tables"
  type        = map(string)
  default     = {}
}

variable "eks_route_table_tags" {
  description = "Additional tags for the EKS route tables"
  type        = map(string)
  default     = {}
}

variable "ocp3_route_table_tags" {
  description = "Additional tags for the OpenShift3 route tables"
  type        = map(string)
  default     = {}
}

variable "enable_tgw_vpc_attachment" {
  description = "Enable an attachment to the Transit Gateway for this VPC"
  type        = bool
  default     = false
}

variable "tgw_id" {
  description = "The id of the Transit Gateway which should be used for VPC attachments"
  type        = string
  default     = ""
}

variable "tgw_additional_routed_vpc_cidr" {
  description = "A list of multiple VPC CIDR blocks for additional routes to be created in direction of the transit gateway"
  type        = list
  default     = []
}

variable "r53_private_zone_name" {
  description = "The name of the main Route53 private zone belonging to this VPC"
  type        = string
  default     = ""
}

variable "r53_private_zone_comment" {
  description = "A comment of the main Route53 private zone belonging to this VPC"
  type        = string
  default     = ""
}

variable "r53_resolver_inbound_endpoint_name" {
  description = "The name of the Route53 inbound resolver necessary for external DNS lookups"
  type        = string
  default     = ""
}

variable "r53_resolver_outbound_endpoint_name" {
  description = "The name of the Route53 outbound resolver necessary for external DNS lookups"
  type        = string
  default     = ""
}

variable "r53_resolver_secgrp_name" {
  description = "The name of the security group belonging to the Route53 inbound resolver"
  type        = string
  default     = ""
}

variable "r53_resolver_rules" {
  description = "A map to configure a name and R53 inbound endpoint ip for R53 rules to do outgoing DNS"
  type        = map
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
