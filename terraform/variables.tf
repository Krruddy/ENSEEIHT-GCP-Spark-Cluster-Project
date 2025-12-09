variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "project_number" {
  type        = string
  description = "GCP project number"
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "Default region"
}

variable "zone" {
  type        = string
  default     = "europe-west1-b"
  description = "Default zone"
}

variable "worker_count" {
  description = "Number of Spark worker nodes"
  default     = 2
}

variable "os_image" {
  description = "OS image to use"
  default     = "debian-cloud/debian-11" 
}

variable "ssh_user" {
  description = "User for SSH access"
  default     = "user"
}

variable "ssh_pub_key_path" {
  description = "Path to public key"
  default     = "~/.ssh/id_rsa.pub"
}

variable "infrastructure_tier" {
  description = "Tier of infrastructure: minimal, standard, or high-performance"
  type        = string
  default     = "minimal"
}

variable "state_bucket" {
  description = "Name of the state bucket"
  type = string
  default = "spark-lab-tfstate"
}

locals {
  machine_specs = {
    minimal = {
      edge_type   = "e2-micro"
      master_type = "e2-small"  
      worker_type = "e2-small"  
      edge_boot_disk   = 15
      master_boot_disk   = 20
      worker_boot_disk   = 20
      hdfs_disk_type = "pd-standard"
      hdfs_disk   = 10
    }
  }
}
