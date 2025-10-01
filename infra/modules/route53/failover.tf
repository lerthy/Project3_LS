# Route53 DNS failover for warm standby
resource "aws_route53_health_check" "primary_api" {
  fqdn              = var.primary_api_dns
  type              = "HTTPS"
  resource_path     = "/contact"
  port              = 443
  request_interval  = 30
  failure_threshold = 3
  tags              = var.tags
}

resource "aws_route53_health_check" "standby_api" {
  fqdn              = var.standby_api_dns
  type              = "HTTPS"
  resource_path     = "/contact"
  port              = 443
  request_interval  = 30
  failure_threshold = 3
  tags              = var.tags
}

resource "aws_route53_record" "api_failover" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }
  health_check_id = aws_route53_health_check.primary_api.id
  records         = [var.primary_api_ip]
  ttl             = 60
}

resource "aws_route53_record" "api_failover_standby" {
  zone_id = var.route53_zone_id
  name    = "api.project3.com"
  type    = "A"

  set_identifier = "standby"
  failover_routing_policy {
    type = "SECONDARY"
  }
  health_check_id = aws_route53_health_check.standby_api.id
  records         = [var.standby_api_ip]
  ttl             = 60
}
