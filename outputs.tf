output "prod_public_ip" {
  description = "Prod instance public IP"
  value       = oci_core_instance.prod.public_ip
}

output "prod_private_ip" {
  description = "Prod instance private IP"
  value       = oci_core_instance.prod.private_ip
}

output "db_public_ip" {
  description = "DB instance public IP"
  value       = oci_core_instance.db.public_ip
}

output "db_private_ip" {
  description = "DB instance private IP"
  value       = oci_core_instance.db.private_ip
}

output "lb_public_ip" {
  description = "Load Balancer public IP"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}
