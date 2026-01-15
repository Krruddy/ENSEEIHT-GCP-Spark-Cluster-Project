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

variable "ssh_public_key_ruddy_desktop" {
  description = "Ruddy's desktop Public SSH key to be added to the VMs."
  type        = string
  sensitive   = true # Prevents Terraform from showing the key in plan outputs
}

variable "ssh_public_key_ruddy_laptop" {
  description = "Ruddy's laptop Public SSH key to be added to the VMs."
  type        = string
  sensitive   = true # Prevents Terraform from showing the key in plan outputs
}

variable "ssh_public_key_landry" {
  description = "Landry's Public SSH key to be added to the VMs."
  type        = string
  sensitive   = true # Prevents Terraform from showing the key in plan outputs
}

variable "ssh_public_key_ansible_runner" {
  description = "Ansible runner's Public SSH key to be added to the VMs."
  type        = string
  sensitive   = true # Prevents Terraform from showing the key in plan outputs
}

variable "infrastructure_tier" {
  description = "Tier of infrastructure: minimal, standard, or high-performance"
  type        = string
  default     = "standard"
}

variable "allowed_ssh_sources" {
  description = "List of CIDR blocks allowed to SSH to the edge node. Use ['0.0.0.0/0'] to allow from anywhere (not recommended for production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_ssh_sources) > 0
    error_message = "At least one CIDR block must be specified for SSH access"
  }
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
    standard = {
      edge_type   = "e2-medium"     
      master_type = "e2-standard-2" 
      worker_type = "e2-standard-2"

      edge_boot_disk  = 20
      master_boot_disk = 30       
      worker_boot_disk = 30
      
      hdfs_disk_type  = "pd-balanced"   # Balanced persistent disk
      hdfs_disk = 50
    }
  }
}
