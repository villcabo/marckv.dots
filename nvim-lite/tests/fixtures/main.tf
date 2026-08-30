terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

variable "stack_prefix" {
  type    = string
  default = "prometheus"
}

resource "docker_network" "metrics" {
  name   = "${var.stack_prefix}_router"
  driver = "bridge"
}
