# Get the Load Balancer information
data "aws_lb" "ingress" {
  name = split("-", data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname)[0]
}

# Route53 record for the domain pointing to the Ingress Controller's Load Balancer
resource "aws_route53_record" "domain" {
  depends_on = [data.kubernetes_service.nginx_ingress]

  zone_id = var.route53_hosted_zone_id
  name    = "*.{var.domain_name}"
  type    = "A"
  alias {
    name                   = "${data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname}."
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
} 
