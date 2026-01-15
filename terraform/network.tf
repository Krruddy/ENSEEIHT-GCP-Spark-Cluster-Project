# Virtual Private Cloud (VPC)
resource "google_compute_network" "vpc" {
  name = "spark-vpc"
  auto_create_subnetworks = false
}

# Public Subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "spark-public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Private Subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "spark-private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Cloud Router
resource "google_compute_router" "router" {
  name    = "spark-router"
  network = google_compute_network.vpc.id
  region  = var.region
}

# Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "spark-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Firewall: Allow SSH to Edge from specified sources only
resource "google_compute_firewall" "allow_ssh_edge" {
  name    = "allow-ssh-edge"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_sources
  target_tags   = ["edge-node"]

  description = "Allow SSH access to edge node from trusted sources only. Configure allowed_ssh_sources variable to restrict access."
}

# Firewall: Allow SSH internal (for bastion access to private nodes)
resource "google_compute_firewall" "allow_internal_ssh" {
  name    = "allow-internal-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.0.0.0/16"]
  description   = "Allow SSH between all nodes in the VPC"
}

# Firewall: Allow Spark cluster communication
resource "google_compute_firewall" "allow_spark_cluster" {
  name    = "allow-spark-cluster"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = [
      "7077",  # Spark Master
      "8080",  # Spark Master Web UI
      "8081",  # Spark Worker Web UI
      "4040",  # Spark Application UI
      "18080", # Spark History Server
    ]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["spark-cluster", "spark-master", "spark-worker"]
  description   = "Allow Spark cluster communication"
}

# Firewall: Allow HDFS communication
resource "google_compute_firewall" "allow_hdfs_cluster" {
  name    = "allow-hdfs-cluster"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = [
      "9000",  # HDFS NameNode IPC
      "9870",  # HDFS NameNode Web UI
      "9864",  # HDFS DataNode
      "9866",  # HDFS DataNode Data Transfer
      "9867",  # HDFS DataNode IPC
    ]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["spark-cluster", "spark-master", "spark-worker"]
  description   = "Allow HDFS cluster communication"
}

# Firewall: Allow ICMP for network diagnostics
resource "google_compute_firewall" "allow_internal_icmp" {
  name    = "allow-internal-icmp"
  network = google_compute_network.vpc.id

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"]
  description   = "Allow ICMP for ping and network diagnostics"
}
