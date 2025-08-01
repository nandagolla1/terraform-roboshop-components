resource "aws_lb_target_group" "main" {
  name        = "${var.project}-${var.environment}-${var.component}"
  port        = local.tg_port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  deregistration_delay = 120

  health_check {
    healthy_threshold = 2
    interval = 5
    matcher = "200-299"
    path = local.health_check_path
    port =local.tg_port
    protocol = "HTTP"
    timeout = 2
    unhealthy_threshold = 3
  }
}

# catalogue instance


resource "aws_instance" "main" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  subnet_id = local.private_subnets_id

  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}

resource "terraform_data" "main" {
  triggers_replace = [
    aws_instance.main.id
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
    }

  provisioner "file" {
    source      = "bootstrap.sh"
    destination = "/tmp/${var.component}.sh"
  }

  provisioner "remote-exec" {
    inline = [ 
        "chmod +x /tmp/${var.component}.sh",
        "sudo sh /tmp/${var.component}.sh ${var.component} ${var.environment}"
     ]
  }
}

# stop the instance
resource "aws_ec2_instance_state" "main" {
  instance_id = aws_instance.main.id
  state       = "stopped"
  depends_on = [ terraform_data.main ]
}

# take ami from the configured instance
resource "aws_ami_from_instance" "main" {
  name               = "${var.project}-${var.environment}-${var.component}"
  source_instance_id = aws_instance.main.id
  depends_on = [ aws_ec2_instance_state.main ]
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
}

# destroy the instance
resource "terraform_data" "main_delete" {
  triggers_replace = [
    aws_instance.main.id
  ]

  #####Make sure you've run aws configure on your laptop.
  provisioner "local-exec" {
    command =    "aws ec2 terminate-instances --instance-ids ${aws_instance.main.id}"
  }
  depends_on = [ aws_ami_from_instance.main ]
}


# aws launch template
resource "aws_launch_template" "main" {
  name = "${var.project}-${var.environment}-${var.component}"
  image_id = aws_ami_from_instance.main.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.sg_id]
  update_default_version = true # each time you update, new version will become default

  tag_specifications {
    resource_type = "instance"
    # EC2 tags created by ASG
    tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-${var.component}"
    }
  )
  }

  tag_specifications {
  resource_type = "volume"

  tags = merge(
  local.common_tags,
  {
    Name = "${var.project}-${var.environment}-${var.component}"
  }
  )
 }

 tags = merge(
  local.common_tags,
  {
    Name = "${var.project}-${var.environment}-${var.component}"
  }
  )
}


##auto scaling group for catalogue
resource "aws_autoscaling_group" "main" {
  name                      = "${var.project}-${var.environment}-${var.component}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 120
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = true
  ##placement_group           = aws_placement_group.test.id
  target_group_arns         = [aws_lb_target_group.main.arn]
  vpc_zone_identifier       = local.private_subnets_ids

  launch_template {
    id = aws_launch_template.main.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-${var.component}"
      }
    )
    content{
      key = tag.key
      value = tag.value
      propagate_at_launch = true
    }
  }

  instance_refresh {
  strategy = "Rolling"
  preferences {
    min_healthy_percentage = 50
  }
  triggers = ["launch_template"]
}

  timeouts{
  delete = "15m"
}  
}


resource "aws_autoscaling_policy" "main" {
  name                   = "${var.project}-${var.environment}-${var.component}"
  autoscaling_group_name = aws_autoscaling_group.main.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }

} 


##  alb listener rule for catalogue target group
resource "aws_lb_listener_rule" "main" {
  listener_arn = local.alb_listener_arn
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = [local.rule_header_url]
    }
  }
}