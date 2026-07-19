data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---- Frontend (Next.js + Nginx) ----

resource "aws_launch_template" "frontend" {
  name_prefix             = "${var.project_name}-frontend-"
  image_id                = data.aws_ami.amazon_linux.id
  instance_type            = var.instance_type
  key_name                 = var.key_name
  vpc_security_group_ids   = [var.frontend_sg_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nodejs npm nginx
    npm install -g pm2
    systemctl enable nginx
    systemctl start nginx
    # TODO: pull your actual frontend app and start it with pm2 here
  EOF
  )
}

resource "aws_autoscaling_group" "frontend" {
  name                = "${var.project_name}-frontend-asg"
  vpc_zone_identifier = values(var.web_subnet_ids)
  target_group_arns   = [var.frontend_target_group_arn]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-frontend"
    propagate_at_launch = true
  }
}

# ---- Backend (Node.js + Express) ----

resource "aws_launch_template" "backend" {
  name_prefix             = "${var.project_name}-backend-"
  image_id                = data.aws_ami.amazon_linux.id
  instance_type            = var.instance_type
  key_name                 = var.key_name
  vpc_security_group_ids   = [var.backend_sg_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nodejs npm
    npm install -g pm2
    # TODO: pull your actual backend app and start it with pm2 here
  EOF
  )
}

resource "aws_autoscaling_group" "backend" {
  name                = "${var.project_name}-backend-asg"
  vpc_zone_identifier = values(var.app_subnet_ids)
  target_group_arns   = [var.backend_target_group_arn]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-backend"
    propagate_at_launch = true
  }
}
