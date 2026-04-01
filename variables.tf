variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID for API key auth"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key PEM file"
  type        = string
}

variable "region" {
  description = "OCI region (e.g. ap-chuncheon-1)"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "ad_index" {
  description = "Availability Domain index (0, 1, or 2). Change if 'out of capacity' error."
  type        = number
  default     = 0
}

variable "prod_ocpu" {
  description = "OCPU count for prod instance"
  type        = number
  default     = 2
}

variable "prod_memory_gb" {
  description = "Memory (GB) for prod instance"
  type        = number
  default     = 12
}

variable "devdb_ocpu" {
  description = "OCPU count for dev/db instance"
  type        = number
  default     = 2
}

variable "devdb_memory_gb" {
  description = "Memory (GB) for dev/db instance"
  type        = number
  default     = 12
}

variable "backend_app_port" {
  description = "Port your backend app listens on (for LB backend set)"
  type        = number
  default     = 8080
}
