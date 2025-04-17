locals {
  # ArgoCD values
  argocd_values = {
    server = {
      extraArgs = ["--insecure"]
      config = {
        url = "https://argocd-nuvolar.${var.domain_name}"
      }
      service = {
        type = "ClusterIP"
      }
    }
  }

  # Prometheus values
  prometheus_values = {
    server = {
      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
      retention = "15d"
    }
  }

  # Grafana values
  grafana_values = {
    adminUser     = "nuvolar-admin"
    adminPassword = "SuperSecret"
    persistence = {
      enabled = false
    }
    resources = {
      limits = {
        cpu    = "500m"
        memory = "512Mi"
      }
      requests = {
        cpu    = "250m"
        memory = "256Mi"
      }
    }
  }

  # CloudWatch values
  cloudwatch_values = {
    metrics_collection_interval = 60
    force_flush_interval = 5
    statsd = {
      metrics_collection_interval = 10
      metrics_aggregation_interval = 60
    }
    instance_type = "t3.micro"
    image = "amazon/cloudwatch-agent:1.247350.0b251302"
    resources = {
      limits = {
        cpu    = "200m"
        memory = "200Mi"
      }
      requests = {
        cpu    = "200m"
        memory = "200Mi"
      }
    }
    ci_version = "1.247350.0b251302"
  }
}
