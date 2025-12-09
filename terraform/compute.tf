# 1. The Edge Node 
resource "google_compute_instance" "edge" {
  name         = "edge-01"
  machine_type = local.machine_specs[var.infrastructure_tier].edge_type
  zone         = var.zone
  tags         = ["edge-node"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = local.machine_specs[var.infrastructure_tier].edge_boot_disk
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.id
    # Including access_config gives it a Public IP
    access_config {} 
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(path.expand(var.ssh_pub_key_path))}"
  }
}

# 2. The Spark Master
resource "google_compute_instance" "master" {
  name         = "spk-mst-01"
  machine_type = local.machine_specs[var.infrastructure_tier].master_type
  zone         = var.zone
  tags         = ["spark-cluster", "spark-master"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = local.machine_specs[var.infrastructure_tier].master_boot_disk
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(path.expand(var.ssh_pub_key_path))}"
  }
}

# 3. Spark Workers - HDFS Storage
resource "google_compute_disk" "hdfs_data" {
  count = var.worker_count
  name  = "hdfs-data-disk-${count.index}"
  type  = local.machine_specs[var.infrastructure_tier].hdfs_disk_type
  size  = local.machine_specs[var.infrastructure_tier].hdfs_disk
  zone  = var.zone
}

# 4. Spark Workers 
resource "google_compute_instance" "workers" {
  count        = var.worker_count
  name         = "spk-wkr-${count.index + 1}"
  machine_type = local.machine_specs[var.infrastructure_tier].worker_type
  zone         = var.zone
  tags         = ["spark-cluster", "spark-worker"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = local.machine_specs[var.infrastructure_tier].worker_boot_disk
    }
  }

  attached_disk {
    source      = google_compute_disk.hdfs_data[count.index].id
    device_name = "hdfs_disk" # Appears as /dev/disk/by-id/google-hdfs_disk
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.id
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(path.expand(var.ssh_pub_key_path))}"
  }
}
