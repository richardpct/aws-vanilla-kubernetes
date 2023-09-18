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

resource "aws_subnet" "public_lb_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_lb_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "subnet_public_lb_a"
  }
}

resource "aws_subnet" "public_lb_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_lb_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "subnet_public_lb_b"
  }
}

resource "aws_subnet" "public_nat_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_nat_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "subnet_public_nat_a"
  }
}

resource "aws_subnet" "public_nat_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public_nat_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "subnet_public_nat_b"
  }
}

resource "aws_subnet" "private_node_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_private_node_a
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "subnet_private_node_a"
  }
}

resource "aws_subnet" "private_node_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_private_node_b
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "subnet_private_node_b"
  }
}

resource "aws_eip" "nat_a" {
  vpc = true

  tags = {
    Name = "eip_nat_a"
  }
}

resource "aws_eip" "nat_b" {
  vpc = true

  tags = {
    Name = "eip_nat_b"
  }
}

resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_nat_a.id

  tags = {
    Name = "nat_gw_a"
  }
}

resource "aws_nat_gateway" "nat_gw_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_nat_b.id

  tags = {
    Name = "nat_gw_b"
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

resource "aws_route_table" "route_nat_a" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw_a.id
  }

  tags = {
    Name = "default_route_nat_a"
  }
}

resource "aws_route_table" "route_nat_b" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw_b.id
  }

  tags = {
    Name = "default_route_nat_b"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_default_route_table.route.id
}

resource "aws_route_table_association" "public_lb_a" {
  subnet_id      = aws_subnet.public_lb_a.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "public_lb_b" {
  subnet_id      = aws_subnet.public_lb_b.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "public_nat_a" {
  subnet_id      = aws_subnet.public_nat_a.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "public_nat_b" {
  subnet_id      = aws_subnet.public_nat_b.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "private_node_a" {
  subnet_id      = aws_subnet.private_node_a.id
  route_table_id = aws_route_table.route_nat_a.id
}

resource "aws_route_table_association" "private_node_b" {
  subnet_id      = aws_subnet.private_node_b.id
  route_table_id = aws_route_table.route_nat_b.id
}
