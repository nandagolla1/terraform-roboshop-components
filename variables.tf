variable "project" {
  default = "roboshop"
}

variable "environment" {
  default = "dev"
}

variable "catalogue_sg_name" {
    type = string
  default = "catalogue"
}

variable "backend_alb_sg_name" {
    type = string
  default = "backend_alb"
}

variable "domain_name" {
  default = "nanda.cyou"
}

variable "component" {
  
}

variable "rule_priority" {
  
}

variable "frontend_alb_sg_name" {
    type = string
  default = "frontend_alb"
}