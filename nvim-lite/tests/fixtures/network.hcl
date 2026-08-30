job "metrics" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      port "http" { to = 9090 }
    }

    task "server" {
      driver = "docker"
      config {
        image = "prom/prometheus:v3.1.0"
        ports = ["http"]
      }
      resources { cpu = 500, memory = 1024 }
    }
  }
}
