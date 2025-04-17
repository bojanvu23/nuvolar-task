# ArgoCD Namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group
  ]
}


# ArgoCD Helm Release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.34.1"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode(local.argocd_values)
  ]

  depends_on = [
    aws_eks_node_group.eks_node_group,
    kubernetes_namespace.argocd,
  ]
}
