# Block Volume for DB data persistence
# 100 GB — Boot volumes are 50GB x2 = 100GB, so this keeps total at 200GB (Free Tier limit)
resource "oci_core_volume" "db_data" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = "bluecollar-db-data"
  size_in_gbs         = 106

  lifecycle {
    prevent_destroy = true
  }
}

# Attach volume to dev/db instance (paravirtualized — simpler than iSCSI on A1 Flex)
resource "oci_core_volume_attachment" "db_data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.db.id
  volume_id       = oci_core_volume.db_data.id
  display_name    = "bluecollar-db-data-attachment"

  is_read_only = false
  is_shareable = false
}
