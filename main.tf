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

resource "aws_security_group" "lb_sg" {
  name        = "load balancer"
  description = "Security group for load balancer"
  vpc_id      = aws_vpc.vpc_infra_1.id

  ingress {
    from_port   = 80 # Allow HTTP traffic
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }
  ingress {
    from_port   = 443 # Allow SSH traffic
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Name" = "lb-sg-${timestamp()}"
  }
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
    protocol        = "tcp"
    from_port       = "8080"
    to_port         = "8080"
    security_groups = [aws_security_group.lb_sg.id]
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


# resource "aws_iam_policy_document" "policy_document" {
#   name        = "WebAppS3"
#   description = "policy for s3"

#   policy = jsonencode({
#     "Version" : "2012-10-17"
#     "Statement" : [
#       {
#         "Action" : ["s3:DeleteObject", "s3:PutObject", "s3:GetObject", "s3:ListAllMyBuckets","s3:ListBucket"]
#         "Effect" : "Allow"
#         "Resource" : ["arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}",
#           "arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*"]
#       }
#     ]
#   })
# }

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


# resource "aws_instance" "ec2" {
#   ami                         = var.amiId
#   instance_type               = var.instance_type
#   subnet_id                   = aws_subnet.public_subnets[0].id
#   key_name                    = var.key_name
#   security_groups             = [aws_security_group.lb_sg.id]
#   iam_instance_profile        = aws_iam_instance_profile.ec2_profile.id
#   associate_public_ip_address = "true"

#   ebs_block_device {
#     device_name           = "/dev/xvda"
#     volume_type           = var.instance_vol_type
#     volume_size           = var.instance_vol_size
#     delete_on_termination = true
#   }
#   # tags = {
#   #   "Name" = "ec2"
#   # }
#   user_data = <<EOF
# #!/bin/bash
# echo "# App Environment Variables"
# echo "DB_URL=jdbc:mysql://${aws_db_instance.rds.address}:3306/${var.db_name}" >> /etc/environment
# echo "DBUSERNAME=${var.db_username}" >> /etc/environment
# echo "DBPASSWORD=${var.db_password}" >> /etc/environment
# echo "S3_BUCKET_NAME=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
# echo "FILESYSTEM_DRIVER=s3" >> /etc/environment
# echo "REGION=${var.provider_region}" >> /etc/environment
# sudo systemctl enable health-check-api.service
# sudo systemctl start health-check-api.service
# sudo systemctl status health-check-api.service
# sudo chown -R www-data:www-data /var/www
# sudo usermod -a -G www-data ubuntu
# EOF
#   tags = {
#     "Name" = "ec2"
#   }
#   depends_on = [aws_db_instance.rds]
# }

data "template_file" "user_data" {
  template = <<EOF
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
}

resource "aws_launch_template" "lt" {
  name          = "asg_launch_config"
  image_id      = var.amiId
  instance_type = var.instance_type
  key_name      = var.key_name
  # associate_public_ip_address = "true"
  #vpc_security_group_ids = [aws_security_group.lb_sg.id]
  user_data = base64encode(data.template_file.user_data.rendered)
  #     templatefile("user.tpl", {user_data = <<EOF
  # #!/bin/bash
  # echo "# App Environment Variables"
  # echo "DB_URL=jdbc:mysql://${aws_db_instance.rds.address}:3306/${var.db_name}" >> /etc/environment
  # echo "DBUSERNAME=${var.db_username}" >> /etc/environment
  # echo "DBPASSWORD=${var.db_password}" >> /etc/environment
  # echo "S3_BUCKET_NAME=${aws_s3_bucket.s3_bucket.id}" >> /etc/environment
  # echo "FILESYSTEM_DRIVER=s3" >> /etc/environment
  # echo "REGION=${var.provider_region}" >> /etc/environment
  # sudo systemctl enable health-check-api.service
  # sudo systemctl start health-check-api.service
  # sudo systemctl status health-check-api.service
  # sudo chown -R www-data:www-data /var/www
  # sudo usermod -a -G www-data ubuntu
  # EOF
  # }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.instance_vol_size
      volume_type           = var.instance_vol_type
      delete_on_termination = true
    }
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.id
  }

}

resource "aws_lb" "lb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
  tags = {
    Application = "HealthCheckApiApplication"
  }
}


data "aws_route53_zone" "selected" {
  name = var.domain_name
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = data.aws_route53_zone.selected.name
  type    = "A"
  # ttl     = "60"
  # records = [aws_lb.lb.dns_name]
  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = true
  }
}

data "aws_iam_policy" "agent_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "agent_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = data.aws_iam_policy.agent_policy.arn
}

# resource "aws_security_group" "lb_sg" {
#   name        = "load balancer"
#   description = "Security group for load balancer"
#   vpc_id      = aws_vpc.webapp_vpc.id

#   ingress {
#     from_port   = 80 # Allow HTTP traffic
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
#   }
#   ingress {
#     from_port   = 443 # Allow SSH traffic
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # Allow traffic from all IP addresses
#   }
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#   tags = {
#     "Name" = "lb-sg-${timestamp()}"
#   }
# }



resource "aws_lb_target_group" "alb_tg" {
  name        = "csye6225-lb-alb-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc_infra_1.id
  target_type = "instance"
  health_check {
    interval = 10
    path     = "/healthz"
    port     = 8080
    protocol = "HTTP"
    matcher  = "200"

  }
}

resource "aws_autoscaling_group" "asg" {
  name = "csye6225-asg-spring2023"
  tag {
    key                 = "webApp"
    value               = "web app"
    propagate_at_launch = true
  }
  vpc_zone_identifier = [aws_subnet.public_subnets[0].id, aws_subnet.public_subnets[1].id, aws_subnet.public_subnets[2].id]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  default_cooldown    = 60
  launch_template {
    id = aws_launch_template.lt.id
  }

  target_group_arns = [
    aws_lb_target_group.alb_tg.arn
  ]
}
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    target_group_arn = aws_lb_target_group.alb_tg.arn
    type             = "forward"
  }
}



resource "aws_autoscaling_policy" "cpu_policy_scaleup" {
  depends_on             = [aws_autoscaling_group.asg]
  name                   = "cpu-policy-scaleup"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "60"
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "cpu_policy_scaledown" {
  name                   = "cpu-policy-scaledown"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "60"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "cpu-alarm-scaleup" {
  alarm_name          = "cpu-alarm-scaleup"
  alarm_description   = "cpu-alarm-scaleup"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.cpu_policy_scaleup.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu-alarm-scaledown" {
  alarm_name          = "cpu-alarm-scaledown"
  alarm_description   = "cpu-alarm-scaledown"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "3"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.asg.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.cpu_policy_scaledown.arn]
}