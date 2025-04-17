# Monitoring Namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    data.aws_eks_cluster.cluster,
    data.aws_eks_cluster_auth.cluster
  ]
}

# Prometheus Operator Helm Release
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "48.1.1"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode(merge(
      local.prometheus_values,
      {
        grafana = local.grafana_values
      }
    ))
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    data.aws_eks_cluster.cluster,
    data.aws_eks_cluster_auth.cluster
  ]
}
