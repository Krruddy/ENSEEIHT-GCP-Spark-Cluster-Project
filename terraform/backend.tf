terraform {
  backend "gcs" {
    # The name of the GCS bucket.
    bucket = "spark-lab-tfstate"

    # Path to state within the bucket
    prefix = "terraform/state"
  }
}
