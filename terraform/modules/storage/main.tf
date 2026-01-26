# Storage Module
# Reusable module for GCS backup storage

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket"
}

variable "storage_class" {
  type        = string
  default     = "STANDARD"
  description = "Storage class (STANDARD, NEARLINE, COLDLINE)"
}

variable "lifecycle_days" {
  type        = number
  default     = 30
  description = "Days to retain objects before deletion"
}

variable "enable_versioning" {
  type        = bool
  default     = true
  description = "Enable object versioning"
}

# GCS Bucket for HDFS backups
resource "google_storage_bucket" "backup" {
  project       = var.project_id
  name          = var.bucket_name
  location      = var.region
  storage_class = var.storage_class
  force_destroy = false

  versioning {
    enabled = var.enable_versioning
  }

  lifecycle_rule {
    condition {
      age = var.lifecycle_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose = "hdfs-backup"
    managed_by = "terraform"
  }
}

# Bucket IAM: Allow HDFS backup service account to write
variable "backup_service_account_email" {
  type        = string
  default     = ""
  description = "Email of service account for backup"
}

resource "google_storage_bucket_iam_member" "backup_writer" {
  count      = var.backup_service_account_email != "" ? 1 : 0
  bucket     = google_storage_bucket.backup.name
  role       = "roles/storage.objectAdmin"
  member     = "serviceAccount:${var.backup_service_account_email}"
}

# Outputs
output "bucket_name" {
  value       = google_storage_bucket.backup.name
  description = "Name of the GCS backup bucket"
}

output "bucket_id" {
  value       = google_storage_bucket.backup.id
  description = "ID of the GCS backup bucket"
}

output "bucket_url" {
  value       = "gs://${google_storage_bucket.backup.name}"
  description = "GCS bucket URL"
}
