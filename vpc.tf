resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = format("%s", var.vpc_name)
  }
}

resource "aws_subnet" "reserved" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  availability_zone_id    = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, index(sort(data.aws_availability_zones.this.zone_ids), each.value))
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name = format("%s-res-%s", var.vpc_name, each.value)
  }
}
resource "aws_subnet" "web" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  availability_zone_id    = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, index(sort(data.aws_availability_zones.this.zone_ids), each.value) + 3)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name = format("%s-web-%s", var.vpc_name, each.value)
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "app" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  availability_zone_id    = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, index(sort(data.aws_availability_zones.this.zone_ids), each.value) + 6)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name = format("%s-app-%s", var.vpc_name, each.value)
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "db" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  availability_zone_id    = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, index(sort(data.aws_availability_zones.this.zone_ids), each.value) + 9)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name = format("%s-db-%s", var.vpc_name, each.value)
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("%s", var.vpc_name)
  }
}

resource "aws_eip" "this" {
  depends_on = [aws_internet_gateway.this]
  for_each   = toset(sort(data.aws_availability_zones.this.zone_ids))

  domain = "vpc"

  tags = {
    Name = format("%s-nat-%s", var.vpc_name, each.value)
  }
}

resource "aws_nat_gateway" "this" {
  depends_on = [aws_internet_gateway.this]
  for_each   = toset(sort(data.aws_availability_zones.this.zone_ids))

  allocation_id = aws_eip.this[each.value].id
  subnet_id     = aws_subnet.web[each.value].id

  tags = {
    Name = format("%s-%s", var.vpc_name, each.value)
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("%s-pub", var.vpc_name)
  }
}

resource "aws_route_table" "private" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  vpc_id = aws_vpc.this.id

  tags = {
    Name = format("%s-prv-%s", var.vpc_name, each.value)
  }
}

resource "aws_route_table_association" "reserved" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  route_table_id = aws_route_table.private[each.value].id
  subnet_id      = aws_subnet.reserved[each.value].id
}

resource "aws_route_table_association" "web" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.web[each.value].id
}

resource "aws_route_table_association" "app" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  route_table_id = aws_route_table.private[each.value].id
  subnet_id      = aws_subnet.app[each.value].id
}

resource "aws_route_table_association" "db" {
  for_each = toset(sort(data.aws_availability_zones.this.zone_ids))

  route_table_id = aws_route_table.private[each.value].id
  subnet_id      = aws_subnet.db[each.value].id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "private" {
  for_each               = toset(sort(data.aws_availability_zones.this.zone_ids))
  route_table_id         = aws_route_table.private[each.value].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}