# Enable Cloud Monitoring and Logging on all VMs
# The monitoring agent will be installed via Ansible

# Notification Channel for Alerts (Email)
resource "google_monitoring_notification_channel" "email" {
  count        = var.monitoring_email != "" ? 1 : 0
  display_name = "Spark Cluster Email Notifications"
  type         = "email"
  labels = {
    email_address = var.monitoring_email
  }
  enabled = true
}

# Alert Policy: High CPU Usage
resource "google_monitoring_alert_policy" "high_cpu" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Spark Cluster - High CPU Usage"
  combiner     = "OR"

  conditions {
    display_name = "CPU usage above 85%"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.monitoring_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "CPU usage on Spark cluster nodes has exceeded 85% for 5 minutes."
    mime_type = "text/markdown"
  }
}

# Alert Policy: High Memory Usage
resource "google_monitoring_alert_policy" "high_memory" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Spark Cluster - High Memory Usage"
  combiner     = "OR"

  conditions {
    display_name = "Memory usage above 90%"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.90

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.monitoring_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Memory usage on Spark cluster nodes has exceeded 90% for 5 minutes."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Disk Usage
resource "google_monitoring_alert_policy" "high_disk" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Spark Cluster - High Disk Usage"
  combiner     = "OR"

  conditions {
    display_name = "Disk usage above 80%"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
      duration        = "600s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = var.monitoring_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "Disk usage on Spark cluster nodes has exceeded 80% for 10 minutes."
    mime_type = "text/markdown"
  }
}

# Alert Policy: Instance Down
resource "google_monitoring_alert_policy" "instance_down" {
  count        = var.enable_monitoring ? 1 : 0
  display_name = "Spark Cluster - Instance Down"
  combiner     = "OR"

  conditions {
    display_name = "Instance is not running"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\") AND metric.type = \"compute.googleapis.com/instance/uptime\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = var.monitoring_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = "A Spark cluster instance has stopped running."
    mime_type = "text/markdown"
  }
}

# Dashboard for Spark Cluster Monitoring
resource "google_monitoring_dashboard" "spark_cluster" {
  count          = var.enable_monitoring ? 1 : 0
  dashboard_json = jsonencode({
    displayName = "Spark Cluster Overview"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "CPU Usage by Instance"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "CPU Usage"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          widget = {
            title = "Memory Usage by Instance"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_MEAN"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Memory Usage"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          yPos   = 4
          widget = {
            title = "Disk I/O by Instance"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Disk I/O"
                scale = "LINEAR"
              }
            }
          }
        },
        {
          width  = 6
          height = 4
          xPos   = 6
          yPos   = 4
          widget = {
            title = "Network Traffic by Instance"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type = \"gce_instance\" AND resource.labels.instance_name = starts_with(\"spk-\")"
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
              timeshiftDuration = "0s"
              yAxis = {
                label = "Network Traffic"
                scale = "LINEAR"
              }
            }
          }
        }
      ]
    }
  })
}
