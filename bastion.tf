# OCI Bastion Service — SSH access to both instances
# Sessions are managed via OCI CLI, not Terraform (TTL of 3h causes state drift)
resource "oci_bastion_bastion" "main" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_id
  target_subnet_id = oci_core_subnet.prod.id
  name             = "bluecollar_bastion"

  client_cidr_block_allow_list = ["0.0.0.0/0"]

  max_session_ttl_in_seconds = 10800 # 3 hours
}

# -----------------------------------------------------------------------
# Sessions are NOT managed in Terraform.
# Use OCI CLI to create sessions as needed:
#
# Connect to PROD instance:
#   oci bastion session create-managed-ssh \
#     --bastion-id <bastion_ocid from outputs> \
#     --target-resource-id <prod_instance_ocid from outputs> \
#     --target-os-username ubuntu \
#     --session-ttl 3600
#
# Connect to DEV/DB instance:
#   oci bastion session create-managed-ssh \
#     --bastion-id <bastion_ocid from outputs> \
#     --target-resource-id <devdb_instance_ocid from outputs> \
#     --target-os-username ubuntu \
#     --session-ttl 3600
#
# After creating a session, OCI returns an SSH proxy command. Use it directly:
#   ssh -o ProxyCommand='...' -i ~/.ssh/id_rsa opc@<private_ip>
# -----------------------------------------------------------------------
