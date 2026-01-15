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

# Firewall: Allow EVERYTHING internal (Cluster chatter)
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal-communication"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/16"] 
}
