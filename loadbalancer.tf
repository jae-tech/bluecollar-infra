# Load Balancer — 10 Mbps Flex (Free Tier)
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_id
  display_name   = "bluecollar-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.lb.id]
  is_private     = false

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

# Backend set — pool of prod instances
resource "oci_load_balancer_backend_set" "prod" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "prod-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.backend_app_port
    url_path          = "/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 5000
    retries           = 3
  }
}

# Backend — prod instance
resource "oci_load_balancer_backend" "prod" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.prod.name
  ip_address       = oci_core_instance.prod.private_ip
  port             = var.backend_app_port
}

# HTTP listener — redirects to HTTPS (or serves directly if no cert yet)
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.prod.name
  port                     = 80
  protocol                 = "HTTP"

  # Redirect all HTTP to HTTPS
  rule_set_names = ["http_to_https"]

  depends_on = [oci_load_balancer_rule_set.http_to_https]
}

# Rule set: HTTP → HTTPS redirect (301)
resource "oci_load_balancer_rule_set" "http_to_https" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "http_to_https"

  items {
    action = "REDIRECT"
    conditions {
      attribute_name  = "PATH"
      attribute_value = "/"
      operator        = "FORCE_LONGEST_PREFIX_MATCH"
    }
    redirect_uri {
      protocol = "HTTPS"
      port     = 443
      host     = "{host}"
      path     = "/{path}"
      query    = "?{query}"
    }
    response_code = 301
  }
}

# -----------------------------------------------------------------------
# HTTPS listener — add after you have a domain + certificate
#
# 1. Upload cert to OCI Certificate Service:
#    oci certs-mgmt certificate create ...
#
# 2. Uncomment and fill in certificate_ids below:
#
# resource "oci_load_balancer_certificate" "main" {
#   load_balancer_id   = oci_load_balancer_load_balancer.main.id
#   certificate_name   = "bluecollar-cert"
#   public_certificate = file("path/to/fullchain.pem")
#   private_key        = file("path/to/privkey.pem")
# }
#
# resource "oci_load_balancer_listener" "https" {
#   load_balancer_id         = oci_load_balancer_load_balancer.main.id
#   name                     = "https-listener"
#   default_backend_set_name = oci_load_balancer_backend_set.prod.name
#   port                     = 443
#   protocol                 = "HTTP"
#   ssl_configuration {
#     certificate_name = oci_load_balancer_certificate.main.certificate_name
#     verify_peer_certificate = false
#   }
# }
# -----------------------------------------------------------------------
