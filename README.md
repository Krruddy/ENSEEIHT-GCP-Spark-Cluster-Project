# ENSEEIHT-GCP-Spark-Cluster-Project

---

This project focuses on automating the deployment of an Apache Spark cluster using Terraform and Ansible on Google Cloud Platform (GCP).

The deployment of the Spark cluster will be done by following the CI/CD pipeline through GitHub Actions.

# Dependencies

Dependencies:

- [Terraform](https://developer.hashicorp.com/terraform)
- [GCLoud](https://docs.cloud.google.com/sdk/docs/install-sdk)

# Configuration

The following variables are used throughout the setup process. Place them in your shell environment or in a script to reuse them easily.

```bash
PROJECT_ID="enseeiht-spark-lab"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

REGION="europe-west1"
TF_STATE_BUCKET="ibdiot-tfstate"

SA_ID="github-actions-sa"
SA_EMAIL="${SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com"

WIF_POOL_ID="github-pool"
WIF_PROVIDER_ID="github-provider"

GITHUB_REPO="Krruddy/ENSEEIHT-GCP-Spark-Cluster-Project"
```

# GCP Setup

`gcloud` is the CLI tool to interact with GCP.

First we login by running:

```bash
gcloud auth login
```

We then create a new project (if not already created):

```bash
gcloud projects create "$PROJECT_ID" \
  --name="$PROJECT_NAME"
```

Then we select the project we want to work on:

```bash
gcloud config set project "$PROJECT_ID"
```

Enable the compute engine API (`compute.googleapis.com`):

```bash
gcloud services enable compute.googleapis.com \
  --project "$PROJECT_ID"
```

> [!NOTE]
> The compute engine API is required to create VMs, disks, networks, etc from anywhere (Web UI, CLI, ...). If not enabled it is impossible to interract meaningfully with the project.


