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

  # SSH: open to internet
  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
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
    destination = "10.0.1.0/24" # db subnet
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

  # Outbound to dev/db: NFS (업로드 파일 공유)
  egress_security_rules {
    protocol    = "6"
    destination = "10.0.1.0/24"
    stateless   = false
    tcp_options {
      min = 2049
      max = 2049
    }
  }
}

# Security list for db instance
resource "oci_core_security_list" "db" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.main.id
  display_name   = "bluecollar-sl-db"

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

  # NFS from prod subnet (업로드 파일 공유)
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/24"
    stateless = false
    tcp_options {
      min = 2049
      max = 2049
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

# DB subnet (public)
resource "oci_core_subnet" "db" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "bluecollar-subnet-db"
  dns_label         = "db"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.db.id]
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
