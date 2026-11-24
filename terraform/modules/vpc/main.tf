data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:az_count caps the zones used, and dev is rebuilt every session. Decide on pinning before prod in #34
  state = "available"

  # Local Zones appear in this list once opted in, and can't host everything this module creates.
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Large, because the VPC CNI gives every pod a VPC IP: a /19 each (8,187 usable).
  private_subnets = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 3, i) }

  # Small, because only load balancers and NAT live here: a /24 each. Starting at 224 puts them in
  # the last /19, so they can't overlap the private ranges, which grow from the bottom.
  public_subnets = { for i, az in local.azs : az => cidrsubnet(var.cidr_block, 8, 224 + i) }

  # Keyed by AZ, so switching to one per AZ adds gateways without replacing the first (ADR 0042).
  nat_azs = var.single_nat_gateway ? slice(local.azs, 0, 1) : local.azs
}

# ---------- VPC ----------

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:Flow logs are billed per GB and nothing reads them yet. Decide before prod in #34
  cidr_block = var.cidr_block

  # Both are needed for nodes to resolve and register with the EKS private endpoint.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name}-vpc" }
}

# AWS's default group allows traffic between its members; adopting it with no rules removes that.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-default-deny" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-igw" }
}

# ---------- Subnets ----------

# No public IP on launch: load balancers and NAT get their own addresses, and no nodes run here.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # The load balancer controller looks for this tag to place internet-facing ALBs.
  tags = {
    Name                     = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  # internal-elb places internal load balancers; the discovery tag tells Karpenter where nodes may go.
  tags = {
    Name                              = "${var.name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = var.cluster_name
  }
}

# ---------- NAT ----------

# The AZ is in the name even in dev, so adding gateways later never renames the first.
resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)

  domain = "vpc"

  tags = { Name = "${var.name}-nat-${each.key}" }

  # On destroy, AWS refuses to detach the IGW while the VPC still has mapped public addresses.
  depends_on = [aws_internet_gateway.this]
}

# Public subnet, because the gateway itself needs a route to the IGW.
resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = { Name = "${var.name}-nat-${each.key}" }

  # The EIP already orders this after the IGW, but nothing above references the public route or its
  # association, so the gateway could be up before it has a path out, or outlive it on destroy.
  depends_on = [aws_route.public_internet, aws_route_table_association.public]
}

# ---------- Public routing ----------

# One table for all AZs: the IGW is regional, so there is no per-AZ target to separate.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-public" }
}

# Separate aws_route resources throughout, because mixing them with inline routes causes conflicts.
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------- Private routing ----------

# One table per AZ even with a single NAT, so per-AZ NAT changes only a route target (ADR 0042).
resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name}-private-${each.key}" }
}

# Single NAT: every AZ uses the first AZ's gateway. Otherwise each AZ stays on its own.
resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? local.azs[0] : each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------- S3 gateway endpoint ----------

# Looked up, so the service name always matches the provider's region.
data "aws_region" "current" {}

# Free, and ECR stores image layers in S3, so those pulls skip the NAT per-GB charge (ADR 0042).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  vpc_endpoint_type = "Gateway"
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"

  # Every private table, or nodes in a missed AZ would silently keep paying for NAT.
  route_table_ids = [for az in local.azs : aws_route_table.private[az].id]

  tags = { Name = "${var.name}-s3" }
}
