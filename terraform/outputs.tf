output "edge_public_ip" {
  description = "Public IP of the Edge Node (Bastion)"
  value       = google_compute_instance.edge.network_interface[0].access_config[0].nat_ip
}

output "edge_private_ip" {
  description = "Internal IP of the Edge Node"
  value       = google_compute_instance.edge.network_interface[0].network_ip
}

output "master_ip" {
  description = "Internal IP of the Master Node"
  value       = google_compute_instance.master.network_interface[0].network_ip
}

output "worker_ips" {
  description = "Internal IPs of Worker Nodes"
  value       = google_compute_instance.workers[*].network_interface[0].network_ip
  #value       = { for instance in google_compute_instance.workers : instance.name => instance.network_interface[0].network_ip }
}