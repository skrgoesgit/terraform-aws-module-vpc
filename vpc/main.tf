terraform {
  required_version = ">= 0.12, < 0.13"
  backend "s3" {}
}

locals {
  max_subnet_length = max(
    length(var.public_subnets),
    length(var.app_subnets),
    length(var.db_subnets),
    length(var.internal_subnets),
    length(var.ecs_subnets),
    length(var.ocp3_subnets),
  )

  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  additional_routing_cidr_blocks_public_subnet   = setproduct(aws_route_table.public.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_frontend_subnet = setproduct(aws_route_table.frontend.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_app_subnet      = setproduct(aws_route_table.app.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_db_subnet       = setproduct(aws_route_table.db.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_internal_subnet = setproduct(aws_route_table.internal.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_ecs_subnet      = setproduct(aws_route_table.ecs.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_eks_subnet      = setproduct(aws_route_table.eks.*.id, var.tgw_additional_routed_vpc_cidr)
  additional_routing_cidr_blocks_ocp3_subnet     = setproduct(aws_route_table.ocp3.*.id, var.tgw_additional_routed_vpc_cidr)

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = element(
    concat(
      aws_vpc_ipv4_cidr_block_association.this.*.vpc_id,
      aws_vpc.this.*.id,
      [""],
    ),
    0,
  )

  vpc_tags = merge(
    var.tags,
    var.vpc_endpoint_tags,
  )
}


########################################
# VPC

resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block                       = var.vpc_cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_hostnames             = var.vpc_enable_dns_hostnames
  enable_dns_support               = var.vpc_enable_dns_support
  enable_classiclink               = var.enable_classiclink
  enable_classiclink_dns_support   = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = var.enable_ipv6

  tags = merge(
    {
      "Name" = format("%s", var.vpc_name)
    },
    var.tags,
    var.vpc_tags,
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = var.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

########################################
# DHCP Options Set

resource "aws_vpc_dhcp_options" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    {
      "Name" = format("%s", var.vpc_name)
    },
    var.tags,
    var.dhcp_options_tags,
  )
}


########################################
# DHCP Options Set Association

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

########################################
# Internet Gateway

resource "aws_internet_gateway" "this" {
  count = var.create_vpc && var.vpc_create_internet_gateway && length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.igw_tags,
    {
      "Name" = format("igw-%s-%s", var.region_code, var.vpc_environment_code)
    },
  )
}

########################################
# NAT Gateway (one per defined public subnet)

# Workaround for interpolation not being able to "short-circuit" the evaluation of the conditional branch that doesn't end up being used
# Source: https://github.com/hashicorp/terraform/issues/11566#issuecomment-289417805
#
# The logical expression would be
#
#    nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : aws_eip.nat.*.id
#
# but then when count of aws_eip.nat.*.id is zero, this would throw a resource not found error on aws_eip.nat.*.id.

locals {
  nat_gateway_ips = split(
    ",",
    var.reuse_nat_ips ? join(",", var.external_nat_ip_ids) : join(",", aws_eip.nat.*.id),
  )
}

resource "aws_eip" "nat" {
  count = var.create_vpc && var.enable_nat_gateway && false == var.reuse_nat_ips ? local.nat_gateway_count : 0
  vpc = true

  tags = merge(
    var.tags,
    var.nat_eip_tags,
    {
      "Name" = format("eip-%s-%s-ngw", element(var.azs_code, var.single_nat_gateway ? 0 : count.index), var.vpc_environment_code)
    },
  )
}

resource "aws_nat_gateway" "this" {
  count = var.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(
    local.nat_gateway_ips,
    var.single_nat_gateway ? 0 : count.index,
  )
  subnet_id = element(
    aws_subnet.public.*.id,
    var.single_nat_gateway ? 0 : count.index,
  )

  tags = merge(
    var.tags,
    var.nat_gateway_tags,
    {
      "Name" = format("ngw-%s-%s-%s", element(var.azs_code, var.single_nat_gateway ? 0 : count.index), var.vpc_environment_code, var.public_subnet_suffix)
    },
  )

  depends_on = [aws_internet_gateway.this]
}

########################################
# Public frontend subnet

resource "aws_subnet" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.public_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.public_subnet_tags,
    {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.public_subnet_suffix))
    },
  )
}

########################################
# Private frontend subnet

resource "aws_subnet" "frontend" {
  count = var.create_vpc && length(var.frontend_subnets) > 0 ? length(var.frontend_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.frontend_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.frontend_subnet_tags,
    {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.frontend_subnet_suffix))
    },
  )
}

########################################
# App subnet

resource "aws_subnet" "app" {
  count = var.create_vpc && length(var.app_subnets) > 0 ? length(var.app_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.app_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.app_subnet_tags,
      {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.app_subnet_suffix))
      },
  )
}

########################################
# Database subnet

resource "aws_subnet" "db" {
  count = var.create_vpc && length(var.db_subnets) > 0 ? length(var.db_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.db_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.db_subnet_tags,
      {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.db_subnet_suffix))
      },
  )
}

resource "aws_db_subnet_group" "db" {
  count = var.create_vpc && length(var.db_subnets) > 0 && var.create_database_subnet_group ? 1 : 0

  name        = format("sng-%s-%s-%s", var.region_code, var.vpc_environment_code, lower(var.db_subnet_suffix))
  description = "Database subnet group for "
  subnet_ids  = aws_subnet.db.*.id

  tags = merge(
    var.tags,
    var.database_subnet_group_tags,
  )
}

########################################
# Internal subnet

resource "aws_subnet" "internal" {
  count = var.create_vpc && length(var.internal_subnets) > 0 ? length(var.internal_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.internal_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.internal_subnet_tags,
      {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.internal_subnet_suffix))
      },
  )
}

########################################
# ECS subnet

resource "aws_subnet" "ecs" {
  count = var.create_vpc && length(var.ecs_subnets) > 0 ? length(var.ecs_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.ecs_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.ecs_subnet_tags,
      {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.ecs_subnet_suffix))
      },
  )
}

########################################
# EKS subnet

resource "aws_subnet" "eks" {
  count = var.create_vpc && length(var.eks_subnets) > 0 ? length(var.eks_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.eks_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.eks_subnet_tags,
      {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.eks_subnet_suffix))
      },
  )
}

########################################
# OCP3 subnet

resource "aws_subnet" "ocp3" {
  count = var.create_vpc && length(var.ocp3_subnets) > 0 ? length(var.ocp3_subnets) : 0

  vpc_id               = local.vpc_id
  cidr_block           = var.ocp3_subnets[count.index]
  availability_zone    = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null

  tags = merge(
    var.tags,
    var.ocp3_subnet_tags,
    {
      "Name" = format("sn-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.ocp3_subnet_suffix))
    },
  )
}

########################################
# Routing (public frontend subnet)

resource "aws_route_table" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.public_route_table_tags,
    {
      "Name" =  format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.public_subnet_suffix))
    },
  )
}

resource "aws_route" "public_internet_gateway" {
  count = var.vpc_create_internet_gateway && var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  route_table_id         = element(aws_route_table.public.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "public_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.public_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_public_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_public_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_public_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (private frontend subnet)

resource "aws_route_table" "frontend" {
  count = var.create_vpc && length(var.frontend_subnets) > 0 ? length(var.frontend_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.frontend_route_table_tags,
    {
      "Name" =  format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.frontend_subnet_suffix))
    },
  )
}

resource "aws_route" "frontend_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.frontend_subnets) > 0 ? length(var.frontend_subnets) : 0

  route_table_id         = element(aws_route_table.frontend.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "frontend_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.frontend_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_frontend_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_frontend_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_frontend_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (app subnet)

resource "aws_route_table" "app" {
  count = var.create_vpc && var.create_app_subnet_route_table && length(var.app_subnets) > 0 ? length(var.app_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.app_route_table_tags,
    {
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.app_subnet_suffix))
    },
  )
}

resource "aws_route" "app_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.app_subnets) > 0 ? length(var.app_subnets) : 0

  route_table_id         = element(aws_route_table.app.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "app_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.app_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_app_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_app_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_app_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (database subnet)

resource "aws_route_table" "db" {
  count = var.create_vpc && var.create_db_subnet_route_table && length(var.db_subnets) > 0 ? length(var.db_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.db_route_table_tags,
    {
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.db_subnet_suffix))
    },
  )
}

resource "aws_route" "db_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.db_subnets) > 0 ? length(var.db_subnets) : 0

  route_table_id         = element(aws_route_table.db.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "db_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.db_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_db_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_db_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_db_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (internal subnet)

resource "aws_route_table" "internal" {
  count = var.create_vpc && var.create_internal_subnet_route_table && length(var.internal_subnets) > 0 ? length(var.internal_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.internal_route_table_tags,
    {
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.internal_subnet_suffix))
    },
  )
}

resource "aws_route" "internal_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.internal_subnets) > 0 ? length(var.internal_subnets) : 0

  route_table_id         = element(aws_route_table.internal.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "internal_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.internal_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_internal_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_internal_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_internal_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (ecs subnet)

resource "aws_route_table" "ecs" {
  count = var.create_vpc && var.create_ecs_subnet_route_table && length(var.ecs_subnets) > 0 ? length(var.ecs_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.ecs_route_table_tags,
    { 
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.ecs_subnet_suffix))
    },
  )
}

resource "aws_route" "ecs_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.ecs_subnets) > 0 ? length(var.ecs_subnets) : 0

  route_table_id         = element(aws_route_table.ecs.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts { 
    create = "10m"
  }
}

resource "aws_route" "ecs_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.ecs_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_ecs_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_ecs_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_ecs_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (eks subnet)

resource "aws_route_table" "eks" {
  count = var.create_vpc && var.create_eks_subnet_route_table && length(var.eks_subnets) > 0 ? length(var.eks_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.eks_route_table_tags,
    {
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.eks_subnet_suffix))
    },
  )
}

resource "aws_route" "eks_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.eks_subnets) > 0 ? length(var.eks_subnets) : 0

  route_table_id         = element(aws_route_table.eks.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "eks_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.eks_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_eks_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_eks_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_eks_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts {
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Routing (ocp3 subnet)

resource "aws_route_table" "ocp3" {
  count = var.create_vpc && var.create_ocp3_subnet_route_table && length(var.ocp3_subnets) > 0 ? length(var.ocp3_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    var.tags,
    var.ocp3_route_table_tags,
    {
      "Name" = format("rt-%s-%s-%s", lower(element(var.azs_code, count.index)), var.vpc_environment_code, lower(var.ocp3_subnet_suffix))
    },
  )
}

resource "aws_route" "ocp3_nat_gateway" {
  count = var.enable_nat_gateway && var.create_vpc && length(var.ocp3_subnets) > 0 ? length(var.ocp3_subnets) : 0

  route_table_id         = element(aws_route_table.ocp3.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this.*.id, count.index)

  timeouts {
    create = "10m"
  }
}

resource "aws_route" "ocp3_transit_gateway_additional_routes" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.ocp3_subnets) > 0 && length(var.tgw_additional_routed_vpc_cidr) > 0 ? length(local.additional_routing_cidr_blocks_ocp3_subnet) : 0

  route_table_id         = local.additional_routing_cidr_blocks_ocp3_subnet[count.index][0]
  destination_cidr_block = local.additional_routing_cidr_blocks_ocp3_subnet[count.index][1]
  transit_gateway_id     = var.tgw_id

  timeouts { 
    create = "10m"
  }

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.this,
  ]
}

########################################
# Route table subnet associations

resource "aws_route_table_association" "public" {
  count = var.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = element(aws_route_table.public.*.id, count.index)
}

resource "aws_route_table_association" "frontend" {
  count = var.create_vpc && length(var.frontend_subnets) > 0 ? length(var.frontend_subnets) : 0

  subnet_id      = element(aws_subnet.frontend.*.id, count.index)
  route_table_id = element(aws_route_table.frontend.*.id, count.index)
}

resource "aws_route_table_association" "app" {
  count = var.create_vpc && length(var.app_subnets) > 0 ? length(var.app_subnets) : 0

  subnet_id      = element(aws_subnet.app.*.id, count.index)
  route_table_id = element(aws_route_table.app.*.id, count.index)
}

resource "aws_route_table_association" "db" {
  count = var.create_vpc && length(var.db_subnets) > 0 ? length(var.db_subnets) : 0

  subnet_id      = element(aws_subnet.db.*.id, count.index)
  route_table_id = element(aws_route_table.db.*.id, count.index)
}

resource "aws_route_table_association" "internal" {
  count = var.create_vpc && length(var.internal_subnets) > 0 ? length(var.internal_subnets) : 0

  subnet_id      = element(aws_subnet.internal.*.id, count.index)
  route_table_id = element(aws_route_table.internal.*.id, count.index)
}

resource "aws_route_table_association" "ecs" {
  count = var.create_vpc && length(var.ecs_subnets) > 0 ? length(var.ecs_subnets) : 0

  subnet_id      = element(aws_subnet.ecs.*.id, count.index)
  route_table_id = element(aws_route_table.ecs.*.id, count.index)
}

resource "aws_route_table_association" "eks" {
  count = var.create_vpc && length(var.eks_subnets) > 0 ? length(var.eks_subnets) : 0

  subnet_id      = element(aws_subnet.eks.*.id, count.index)
  route_table_id = element(aws_route_table.eks.*.id, count.index)
}

resource "aws_route_table_association" "ocp3" {
  count = var.create_vpc && length(var.ocp3_subnets) > 0 ? length(var.ocp3_subnets) : 0

  subnet_id      = element(aws_subnet.ocp3.*.id, count.index)
  route_table_id = element(aws_route_table.ocp3.*.id, count.index)
}

########################################
# Transit gateway attachments

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.enable_tgw_vpc_attachment && var.create_vpc && length(var.internal_subnets) > 0 ? 1 : 0

  subnet_ids         = aws_subnet.internal.*.id
  transit_gateway_id = var.tgw_id
  vpc_id             = local.vpc_id

  tags = merge(
    var.tags,
    {
      "Name" = format("tgwattach-%s-all-vpc-%s", var.region_code, lower(var.vpc_environment_code)) 
    },
  )
}

########################################
# Route53 private zone

resource "aws_route53_zone" "this" {
  name    = var.r53_private_zone_name
  comment = var.r53_private_zone_comment

  vpc {
    vpc_id = local.vpc_id
  }
}

########################################
# Route53 resolver

resource "aws_route53_resolver_endpoint" "r53rslv-ep-in" {
  count     = var.create_vpc && length(var.internal_subnets) > 0 ? 1 : 0
  name      = var.r53_resolver_inbound_endpoint_name
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.r53rslv.id,
  ]

  dynamic "ip_address" {
    for_each = aws_subnet.internal.*.id

    content {
      subnet_id = ip_address.value
      ip = cidrhost(aws_subnet.internal[ip_address.key].cidr_block, 8)
    }
  }
}

resource "aws_route53_resolver_endpoint" "r53rslv-ep-out" {
  count     = var.create_vpc && length(var.internal_subnets) > 0 ? 1 : 0
  name      = var.r53_resolver_outbound_endpoint_name
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.r53rslv.id,
  ]

  dynamic "ip_address" {
    for_each = aws_subnet.internal.*.id

    content {
      subnet_id = ip_address.value
      ip = cidrhost(aws_subnet.internal[ip_address.key].cidr_block, 9)
    }
  }
}

resource "aws_security_group" "r53rslv" {
  name        = var.r53_resolver_secgrp_name
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_resolver_rule" "r53rslv-rules" {
  for_each             = var.r53_resolver_rules
  name                 = each.key
  domain_name          = each.value[1]
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.r53rslv-ep-out[0].id

  dynamic "target_ip" {
    for_each = each.value[0]
    
    content {
      ip = target_ip.value
    }
  }
}

resource "aws_route53_resolver_rule_association" "r53rslv" {
  for_each         = var.r53_resolver_rules
  resolver_rule_id = aws_route53_resolver_rule.r53rslv-rules[each.key].id
  vpc_id           = local.vpc_id
}
