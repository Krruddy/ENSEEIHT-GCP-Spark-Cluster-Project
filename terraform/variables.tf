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
  type        = number
  default     = 10
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

locals {
  machine_specs = {
    minimal = {
      edge_type   = "e2-standard-2"
      master_type = "e2-standard-2"  
      worker_type = "e2-micro"  # Max 15 due to 500 disk limit
      edge_boot_disk   = 30
      master_boot_disk   = 20
      worker_boot_disk   = 15
      hdfs_disk_type = "pd-standard"
      hdfs_disk   = 15
    }
    standard = {
      edge_type   = "e2-standard-2"     
      master_type = "e2-standard-2" 
      worker_type = "e2-standard-2" # Max 10 due to 500 disk limit

      edge_boot_disk  = 30
      master_boot_disk = 20       
      worker_boot_disk = 20
      
      hdfs_disk_type  = "pd-balanced"   # Balanced persistent disk
      hdfs_disk = 25
    }
    standard_plus = { 
      edge_type   = "e2-standard-2"     
      master_type = "e2-standard-2" 
      worker_type = "e2-standard-4" # Max 7 due to CPU 32 limit

      edge_boot_disk  = 30
      master_boot_disk = 20       
      worker_boot_disk = 20
      
      hdfs_disk_type  = "pd-balanced"   # Balanced persistent disk
      hdfs_disk = 40
    }
    high-performance = {
      edge_type   = "e2-standard-4"
      master_type = "e2-standard-4"
      worker_type = "e2-standard-4"

      edge_boot_disk   = 30
      master_boot_disk = 20
      worker_boot_disk = 20

      hdfs_disk_type = "pd-ssd"
      hdfs_disk      = 25
    }
  }
}
