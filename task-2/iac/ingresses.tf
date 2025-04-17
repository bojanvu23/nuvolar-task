# #ClusterIssuer for Let's Encrypt DNS-01
resource "kubernetes_manifest" "letsencrypt_dns_clusterissuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-dns"
    }
    spec = {
      acme = {
        email  = "bojan.vujasin@gmail.com"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-dns-account-key"
        }
        solvers = [
          {
            dns01 = {
              route53 = {
                region       = var.region
                hostedZoneID = var.route53_hosted_zone_id
              }
            }
          }
        ]
      }
    }
  }
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    helm_release.cert_manager,
    kubernetes_namespace.cert_manager
  ]
}


# ArgoCD Ingress
resource "kubernetes_ingress_v1" "argocd" {
  metadata {
    name      = "argocd"
    namespace = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "cert-manager.io/cluster-issuer"           = "letsencrypt-dns"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["argocd-nuvolar.${var.domain_name}"]
      secret_name = "argocd-tls"
    }

    rule {
      host = "argocd-nuvolar.${var.domain_name}"
      http {
        path {
          path = "/"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd,
    kubernetes_manifest.letsencrypt_dns_clusterissuer
  ]
}

# Grafana Ingress
resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "cert-manager.io/cluster-issuer"           = "letsencrypt-dns"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["grafana-nuvolar.${var.domain_name}"]
      secret_name = "grafana-tls"
    }

    rule {
      host = "grafana-nuvolar.${var.domain_name}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_manifest.letsencrypt_dns_clusterissuer
  ]
}
