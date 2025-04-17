# Logging Namespace
resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      "app.kubernetes.io/name" = "logging"
    }
  }
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group
  ]
}

# Fluent Bit IAM Role
resource "aws_iam_role" "fluent_bit" {
  name = "${var.cluster_name}-fluent-bit"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:logging:fluent-bit"
          }
        }
      }
    ]
  })
}

# Fluent Bit IAM Policy
resource "aws_iam_policy" "fluent_bit" {
  name        = "${var.cluster_name}-fluent-bit"
  description = "Policy for Fluent Bit to write logs to CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"
      }
    ]
  })
}

# Attach Fluent Bit Policy to Role
resource "aws_iam_role_policy_attachment" "fluent_bit" {
  policy_arn = aws_iam_policy.fluent_bit.arn
  role       = aws_iam_role.fluent_bit.name
}

# Fluent Bit Service Account
resource "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.logging.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
    }
  }
}

# Fluent Bit Cluster Role
resource "kubernetes_cluster_role" "fluent_bit" {
  metadata {
    name = "fluent-bit"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

# Fluent Bit Cluster Role Binding
resource "kubernetes_cluster_role_binding" "fluent_bit" {
  metadata {
    name = "fluent-bit"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluent_bit.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluent_bit.metadata[0].name
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
}

#CloudWatch Log Group
resource "aws_cloudwatch_log_group" "cloudwatch_log_group" {
  name              = "/aws/eks/${var.cluster_name}/containers"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-eks-log-group"
  })
}

# Fluent Bit ConfigMap
resource "kubernetes_config_map" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush        1
          Log_Level    info
          Daemon       off
          Parsers_File parsers.conf
          HTTP_Server  On
          HTTP_Listen  0.0.0.0
          HTTP_Port    2020

      [INPUT]
          Name              tail
          Tag               kube.*
          Path              /var/log/containers/*.log
          Parser            docker
          DB                /var/log/flb_kube.db
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On
          Refresh_Interval  10

      [FILTER]
          Name                kubernetes
          Match               kube.*
          Kube_URL            https://kubernetes.default.svc:443
          Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
          Kube_Tag_Prefix     kube.var.log.containers.
          Merge_Log           On
          Merge_Log_Key       log_processed
          K8S-Logging.Parser  On
          K8S-Logging.Exclude On

      [OUTPUT]
          Name            cloudwatch
          Match           *
          region          ${var.region}
          log_group_name  /aws/eks/${var.cluster_name}/containers
          log_stream_name ${var.cluster_name}-fluent-bit
          auto_create_group true
          log_format      json/emf
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name   docker
          Format json
          Time_Key time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    EOT
  }
}

# Fluent Bit DaemonSet
resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "fluent-bit"
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "fluent-bit"
        }
      }

      spec {
        service_account_name = "fluent-bit"
        container {
          name  = "fluent-bit"
          image = "fluent/fluent-bit:2.1.10"
          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }
          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }
          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }
          volume_mount {
            name       = "fluent-bit-state"
            mount_path = "/var/log/fluent-bit"
          }
        }
        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        volume {
          name = "fluent-bit-config"
          config_map {
            name = kubernetes_config_map.fluent_bit_config.metadata[0].name
          }
        }
        volume {
          name = "fluent-bit-state"
          empty_dir {}
        }
      }
    }
  }
}

# CloudWatch Dashboard for Public Log Access
resource "aws_cloudwatch_dashboard" "public_logs" {
  dashboard_name = "${var.cluster_name}-public-logs"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "log"
        x      = 0
        y      = 0
        width  = 24
        height = 6
        properties = {
          view   = "table"
          region = var.region
          query  = "SOURCE '/aws/eks/${var.cluster_name}/containers' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          title  = "Recent Container Logs"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          view   = "table"
          region = var.region
          query  = "SOURCE '/aws/eks/${var.cluster_name}/containers' | stats count(*) by kubernetes.pod_name | sort count(*) desc | limit 10"
          title  = "Top 10 Pods by Log Volume"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          view   = "timeSeries"
          region = var.region
          query  = "SOURCE '/aws/eks/${var.cluster_name}/containers' | stats count(*) by bin(1h) | sort bin asc"
          title  = "Log Volume Over Time"
        }
      }
    ]
  })
}

# IAM Policy for Public Dashboard Access
resource "aws_iam_policy" "public_dashboard" {
  name        = "${var.cluster_name}-public-dashboard"
  description = "Policy for public access to CloudWatch dashboard"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/*"
      }
    ]
  })
}

# IAM Role for Public Dashboard Access
resource "aws_iam_role" "public_dashboard" {
  name = "${var.cluster_name}-public-dashboard"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
      }
    ]
  })
}

# Attach Policy to Public Dashboard Role
resource "aws_iam_role_policy_attachment" "public_dashboard" {
  policy_arn = aws_iam_policy.public_dashboard.arn
  role       = aws_iam_role.public_dashboard.name
}

# Output the dashboard URL
output "public_dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${var.cluster_name}-public-logs"
}
