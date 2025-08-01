data "aws_ami" "joindevops" {
  most_recent = true
  owners = [ "973714476881" ]

  filter {
    name   = "name"
    values = ["RHEL-9-DevOps-Practice"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.project}/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "sg_id" {
  name = "/${var.project}/${var.environment}/${var.component}-sg-group"
}

data "aws_ssm_parameter" "private_subnets" {
  name  = "/${var.project}/${var.environment}/private_subnets"
}

data "aws_ssm_parameter" "backend_alb_listener_arn" {
  name  = "/${var.project}/${var.environment}/${var.backend_alb_sg_name}"
}

data "aws_ssm_parameter" "frontend_alb_listener_arn" {
  name  = "/${var.project}/${var.environment}/${var.frontend_alb_sg_name}"
}