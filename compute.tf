locals {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.ad_index].name
  base_image_id       = data.oci_core_images.oracle_linux_arm.images[0].id
}

# Prod instance — backend server
resource "oci_core_instance" "prod" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = "bluecollar-prod"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.prod_ocpu
    memory_in_gbs = var.prod_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.base_image_id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.prod.id
    assign_public_ip = true
    display_name     = "bluecollar-prod-vnic"
    hostname_label   = "prod"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(templatefile("${path.module}/cloud-init/prod.yaml", { db_private_ip = var.db_private_ip }))
  }

  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [metadata, source_details]
  }
}

# DB instance — database server
resource "oci_core_instance" "db" {
  compartment_id      = var.compartment_id
  availability_domain = local.availability_domain
  display_name        = "bluecollar-db"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.db_ocpu
    memory_in_gbs = var.db_memory_gb
  }

  source_details {
    source_type             = "image"
    source_id               = local.base_image_id
    boot_volume_size_in_gbs = 50
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.db.id
    assign_public_ip = true
    display_name     = "bluecollar-db-vnic"
    hostname_label   = "db"
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init/db.yaml"))
  }

  preserve_boot_volume = false

  lifecycle {
    ignore_changes = [metadata, source_details]
  }
}
