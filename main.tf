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

# Database security group
resource "aws_security_group" "db_sg" {
  name        = "database"
  description = "Security group for RDS instance for database"
  vpc_id      = aws_vpc.vpc_infra_1.id
  //vpc_id      = vpc_infra_1
  ingress {
    protocol        = "tcp"
    from_port       = "3306"
    to_port         = "3306"
    security_groups = [aws_security_group.app_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "database-sg"
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "my_private_bucket" {
  bucket                  = aws_s3_bucket.s3_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "my_bucket_lifecycle" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    id     = "transition-to-standard-ia"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypt" {
  bucket = aws_s3_bucket.s3_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


#iam role for ec2
resource "aws_iam_role" "ec2_role" {
  description        = "Policy for EC2 instance"
  name               = "tf-ec2-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17", 
  "Statement": [
    {
      "Action": "sts:AssumeRole", 
      "Effect": "Allow", 
      "Principal": {
        "Service": "ec2.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    "Name" = "ec2-iam-role"
  }
}



#policy document
data "aws_iam_policy_document" "policy_document" {
  version = "2012-10-17"
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.s3_bucket.arn}",
      "${aws_s3_bucket.s3_bucket.arn}/*"
    ]
  }
  depends_on = [aws_s3_bucket.s3_bucket]
}

#iam policy for role
resource "aws_iam_role_policy" "s3_policy" {
  name       = "tf-s3-policy"
  role       = aws_iam_role.ec2_role.id
  policy     = data.aws_iam_policy_document.policy_document.json
  depends_on = [aws_s3_bucket.s3_bucket]
}

#db subnet group for rds
resource "aws_db_subnet_group" "db_subnet_group" {
  description = "Subnet group for RDS"
  subnet_ids  = [aws_subnet.private_subnets[0].id, aws_subnet.private_subnets[1].id, aws_subnet.private_subnets[2].id]
  tags = {
    "Name" = "db-subnet-group"
  }
}

#rds
resource "aws_db_instance" "rds" {
  allocated_storage      = var.db_storage_size
  identifier             = "csye6225"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  instance_class         = var.db_instance_class
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  publicly_accessible    = var.db_public_access
  multi_az               = var.db_multiaz
  parameter_group_name   = aws_db_parameter_group.rds-pg.name
  skip_final_snapshot    = true
  tags = {
    "Name" = "rds"
  }
}

#RDS Parameter Group
resource "aws_db_parameter_group" "rds-pg" {
  name        = "mrds-pg"
  family      = "mysql8.0"
  description = "Custom parameter group for MySQL 8.0"

}

#iam instance profile for ec2
resource "aws_iam_instance_profile" "ec2_profile" {
  role = aws_iam_role.ec2_role.name
}


resource "aws_instance" "ec2" {
  ami                         = var.amiId
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnets[0].id
  key_name                    = var.key_name
  security_groups             = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.id
  associate_public_ip_address = "true"

  ebs_block_device {
    device_name           = "/dev/xvda"
    volume_type           = var.instance_vol_type
    volume_size           = var.instance_vol_size
    delete_on_termination = true
  }
  # tags = {
  #   "Name" = "ec2"
  # }
  user_data = <<EOF
#!/bin/bash
echo "# App Environment Variables"
echo "DB_URL=jdbc:mysql://${aws_db_instance.rds.address}:3306/${var.db_name}" >> /etc/environment
echo "DBUSERNAME=${var.db_username}" >> /etc/environment
echo "DBPASSWORD=${var.db_password}" >> /etc/environment
echo "S3_BUCKET_NAME=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
echo "FILESYSTEM_DRIVER=s3" >> /etc/environment
echo "REGION=${var.provider_region}" >> /etc/environment
sudo systemctl enable health-check-api.service
sudo systemctl start health-check-api.service
sudo systemctl status health-check-api.service
sudo chown -R www-data:www-data /var/www
sudo usermod -a -G www-data ubuntu
EOF
  tags = {
    "Name" = "ec2"
  }
  depends_on = [aws_db_instance.rds]
}
