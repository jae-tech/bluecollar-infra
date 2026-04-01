resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "bluecollar-vcn"
  dns_label      = "bluecollar"
}

resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-rt-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}

# Security list for prod instance
resource "oci_core_security_list" "prod" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-sl-prod"

  # SSH: Bastion only (VCN-internal injection — do NOT open to 0.0.0.0/0)
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "10.0.0.0/16"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # App traffic from Load Balancer subnet
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.2.0/24" # LB subnet CIDR
    stateless = false
    tcp_options {
      min = var.backend_app_port
      max = var.backend_app_port
    }
  }

  # Outbound: HTTPS (Docker pull, apt)
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Outbound: HTTP (apt)
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Outbound: DNS TCP
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 53
      max = 53
    }
  }

  # Outbound: DNS UDP
  egress_security_rules {
    protocol    = "17" # UDP
    destination = "0.0.0.0/0"
    stateless   = false
    udp_options {
      min = 53
      max = 53
    }
  }

  # Outbound to dev/db: PostgreSQL
  egress_security_rules {
    protocol    = "6"
    destination = "10.0.1.0/24" # devdb subnet
    stateless   = false
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  # Outbound to dev/db: Redis
  egress_security_rules {
    protocol    = "6"
    destination = "10.0.1.0/24"
    stateless   = false
    tcp_options {
      min = 6379
      max = 6379
    }
  }
}

# Security list for dev/db instance
resource "oci_core_security_list" "devdb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-sl-devdb"

  # SSH: Bastion only
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/16"
    stateless = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  # PostgreSQL from prod subnet
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/24" # prod subnet
    stateless = false
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  # Redis from prod subnet
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/24"
    stateless = false
    tcp_options {
      min = 6379
      max = 6379
    }
  }

  # Outbound: HTTPS
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Outbound: HTTP
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  # Outbound: DNS TCP
  egress_security_rules {
    protocol    = "6"
    destination = "0.0.0.0/0"
    stateless   = false
    tcp_options {
      min = 53
      max = 53
    }
  }

  # Outbound: DNS UDP
  egress_security_rules {
    protocol    = "17"
    destination = "0.0.0.0/0"
    stateless   = false
    udp_options {
      min = 53
      max = 53
    }
  }
}

# Security list for load balancer subnet
resource "oci_core_security_list" "lb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-sl-lb"

  # HTTP from internet
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS from internet
  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  # Outbound to prod instance
  egress_security_rules {
    protocol    = "6"
    destination = "10.0.0.0/24"
    stateless   = false
    tcp_options {
      min = var.backend_app_port
      max = var.backend_app_port
    }
  }
}

# Prod subnet (public)
resource "oci_core_subnet" "prod" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.0.0/24"
  display_name      = "bluecollar-subnet-prod"
  dns_label         = "prod"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.prod.id]
}

# Dev/DB subnet (public)
resource "oci_core_subnet" "devdb" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "bluecollar-subnet-devdb"
  dns_label         = "devdb"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.devdb.id]
}

# Load Balancer subnet (public)
resource "oci_core_subnet" "lb" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.2.0/24"
  display_name      = "bluecollar-subnet-lb"
  dns_label         = "lb"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.lb.id]
}
