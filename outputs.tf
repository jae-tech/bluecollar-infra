output "prod_public_ip" {
  description = "Prod instance public IP"
  value       = oci_core_instance.prod.public_ip
}

output "prod_private_ip" {
  description = "Prod instance private IP"
  value       = oci_core_instance.prod.private_ip
}

output "prod_instance_id" {
  description = "Prod instance OCID (use for Bastion session)"
  value       = oci_core_instance.prod.id
}

output "devdb_public_ip" {
  description = "Dev/DB instance public IP"
  value       = oci_core_instance.devdb.public_ip
}

output "devdb_private_ip" {
  description = "Dev/DB instance private IP"
  value       = oci_core_instance.devdb.private_ip
}

output "devdb_instance_id" {
  description = "Dev/DB instance OCID (use for Bastion session)"
  value       = oci_core_instance.devdb.id
}

output "lb_public_ip" {
  description = "Load Balancer public IP"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

output "bastion_id" {
  description = "Bastion OCID (use for creating sessions)"
  value       = oci_bastion_bastion.main.id
}

output "bastion_session_cmd_prod" {
  description = "OCI CLI command to create SSH session to prod instance"
  value       = <<-EOT
    oci bastion session create-managed-ssh \
      --bastion-id ${oci_bastion_bastion.main.id} \
      --target-resource-id ${oci_core_instance.prod.id} \
      --target-os-username ubuntu \
      --session-ttl 3600
  EOT
}

output "bastion_session_cmd_devdb" {
  description = "OCI CLI command to create SSH session to dev/db instance"
  value       = <<-EOT
    oci bastion session create-managed-ssh \
      --bastion-id ${oci_bastion_bastion.main.id} \
      --target-resource-id ${oci_core_instance.devdb.id} \
      --target-os-username ubuntu \
      --session-ttl 3600
  EOT
}
