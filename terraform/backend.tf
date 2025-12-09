terraform {
  backend "gcs" {
    # The name of the GCS bucket.
    bucket = var.state_bucket

    # Path to state within the bucket
    prefix = "terraform/state"
  }
}
