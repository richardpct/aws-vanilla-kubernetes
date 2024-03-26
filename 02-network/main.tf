data "aws_availability_zones" "available" {}

resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = var.subnet_public

  tags = {
    Name = "subnet_public"
  }
}

resource "aws_default_route_table" "route" {
  default_route_table_id = aws_vpc.my_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "default route"
  }
}

resource "aws_subnet" "public_lb" {
  count             = length(var.subnet_public_lb)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_lb[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_public_lb_${count.index}"
  }
}

resource "aws_subnet" "public_nat" {
  count             = length(var.subnet_public_nat)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_nat[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_public_nat_${count.index}"
  }
}

resource "aws_subnet" "private_lb" {
  count             = length(var.subnet_private_lb)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_private_lb[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_private_lb_${count.index}"
  }
}

resource "aws_subnet" "private_worker" {
  count             = length(var.subnet_private_worker)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_private_worker[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_private_worker_${count.index}"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.subnet_public_nat)
  domain = "vpc"

  tags = {
    Name = "eip_nat_${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.subnet_public_nat)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public_nat[count.index].id

  tags = {
    Name = "nat_gw_${count.index}"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "custom_route"
  }
}

resource "aws_route_table" "route_nat" {
  count  = length(var.subnet_public_nat)
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = {
    Name = "default_route_nat_${count.index}"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_default_route_table.route.id
}

resource "aws_route_table_association" "public_lb" {
  count          = length(var.subnet_public_lb)
  subnet_id      = aws_subnet.public_lb[count.index].id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "public_nat" {
  count          = length(var.subnet_public_nat)
  subnet_id      = aws_subnet.public_nat[count.index].id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "private_worker" {
  count          = length(var.subnet_public_nat)
  subnet_id      = aws_subnet.private_worker[count.index].id
  route_table_id = aws_route_table.route_nat[count.index].id
}
