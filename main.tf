resource "aws_vpc" "vpc_infra_1" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = var.vpc_enable_dns_hostnames
  enable_dns_support   = var.vpc_enable_dns_support

  tags = {
    Name        = var.vpc_display_name
    description = "vpc for infrastructue"
  }
}

resource "aws_internet_gateway" "infra_gw" {
  depends_on = [aws_vpc.vpc_infra_1]
  vpc_id     = aws_vpc.vpc_infra_1.id
  tags = {
    Name        = var.infra_display_name
    description = "gateway for infrastructue"
  }
}

resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.vpc_infra_1.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.vpc_infra_1.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.vpc_infra_1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.infra_gw.id
  }

  tags = {
    Name = var.route_display_name
  }
}

resource "aws_route_table" "second_rt_private" {
  vpc_id = aws_vpc.vpc_infra_1.id

  tags = {
    Name = var.route_display_name2
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt.id
}

resource "aws_route_table_association" "private_subnet_association" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = aws_route_table.second_rt_private.id
}

resource "aws_security_group" "app_sg" {
  name        = "application"
  description = "Security group for EC2 instance with web application"
  vpc_id      = aws_vpc.vpc_infra_1.id
  ingress {
    protocol    = "tcp"
    from_port   = "22"
    to_port     = "22"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = "80"
    to_port     = "80"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = "443"
    to_port     = "443"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    protocol    = "tcp"
    from_port   = "8080"
    to_port     = "8080"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "application-sg"
  }
}

resource "aws_instance" "ec2" {
  ami                         = var.amiId
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  key_name                    = var.key_name
  security_groups             = [aws_security_group.app_sg.id]
  associate_public_ip_address = "true"

  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_type           = var.instance_vol_type
    volume_size           = var.instance_vol_size
    delete_on_termination = true
  }
  tags = {
    "Name" = "ec2"
  }
}
