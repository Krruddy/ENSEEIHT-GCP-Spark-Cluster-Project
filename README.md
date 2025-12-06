# ENSEEIHT-GCP-Spark-Cluster-Project

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

# GitHub - GCP Credentials

In order to enable the communication between GitHub Actions and GCP we have to do the following steps:

- [ ] [[#Enable the Security APIs]]
- [ ] [[#Create the Service Account]]
- [ ] [[#Set up the Workload Identity Federation]]
    - [ ] [[#Create the Workload Identity Pool]]
    - [ ] [[#Create the Workload Identity Provider]]
    - [ ] [[#Binding (Allow Impersonation)]]
- [ ] [[#Get the Provider ID]]

## Enable the Security APIs

In order to let an external system (GitHub Actions) talk to Google without a password (using Workload Identity Federation), the three following APIs have to be enabled:

- [Identity and Access Management (IAM) API](https://docs.cloud.google.com/iam/docs/reference/rest): Manages identity and access control for Google Cloud resources, including the creation of service accounts, which you can use to authenticate to Google and make API calls.
- [Security Token Service API](https://docs.cloud.google.com/iam/docs/reference/sts/rest): The Security Token Service exchanges Google or third-party credentials (here a OIDC token) for a short-lived access token to Google Cloud resources.
- [IAM Service Account Credentials API](https://docs.cloud.google.com/iam/docs/reference/credentials/rest): Creates short-lived credentials for impersonating IAM service accounts.

```bash
gcloud services enable iamcredentials.googleapis.com \
                       sts.googleapis.com \
                       iam.googleapis.com \
                       --project "$PROJECT_ID"
```

## Create the Service Account

This step creates the service account that will be used by GitHub Actions to login to GCP, and gives it the necessary permissions to create manage the infrastructure.

We give this account three roles:

- [Compute Engine IAM roles and permissions](https://docs.cloud.google.com/compute/docs/access/iam): Grants full control over Compute Engine resources (VMs, Disks, Networks, Firewalls).
- [IAM roles for Cloud Storage](https://docs.cloud.google.com/storage/docs/access-control/iam-roles): Grants full control over Cloud Storage buckets and objects.
- [Roles for service account authentication](https://docs.cloud.google.com/iam/docs/service-account-permissions): Grants permission to assign service accounts to resources.

To be more specific about the need for `roles/iam.serviceAccountUser`, without it Terraform is allowed to create the VM (via compute.admin), but it is forbidden from assigning an identity to it. The deployment would fail with a permissions error.

> [!NOTE]
> Currently the service account has very broad permissions (e.g., compute.admin). In a production environment, it is recommended to follow the principle of least privilege and only assign the necessary permissions required for the tasks at hand.

```bash
# Create the account
gcloud iam service-accounts create "$SA_ID" \
  --project "$PROJECT_ID" \
  --display-name "GitHub Actions Service Account" \
  --description="Service Account to be used by GitHub Actions via Workload Identity Federation"

# Give it power (e.g., to create VMs and Networks)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"
```

## Set up the Workload Identity Federation

The [Workload Identity Federation](https://docs.cloud.google.com/iam/docs/workload-identity-federation) is the mechanism that allows GitHub Actions to authenticate to GCP without using long-lived credentials (e.g., service account keys).

> [!NOTE]
> Without Workload Identity Federation, we would have to use service account keys, which are long-lived credentials that pose a security risk if leaked. Workload Identity Federation allows for secure, short-lived access to GCP resources.

### Create the Workload Identity Pool

A [workload identity pool](https://docs.cloud.google.com/iam/docs/workload-identity-federation#pools) is an entity that lets you manage external identities.

Usually, one would create a pool per environment (e.g., production, staging, development, etc.), but this project doesn't require the existence of multiple environments, so only one pool is created.

> [!NOTE]
> One pool can contain multiple providers (e.g., GitHub, Azure AD, etc.), to support mechanisms such multi-cloud failovers, or key rotation.

```bash
gcloud iam workload-identity-pools create "$WIF_POOL_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Pool"
```

### Create the Workload Identity Provider

A [workload identity provider](https://docs.cloud.google.com/iam/docs/workload-identity-federation#providers) is an entity that describes a relationship between Google Cloud and the IdP (here GitHub).

The parameter `--issuer-uri` is the URL of the OIDC provider (here GitHub Actions) that Google Cloud will trust.

> ⚠️ What is the purpose of `--attribute-mapping`?

```bash
gcloud iam workload-identity-pools providers create-oidc "$WIF_PROVIDER_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$WIF_POOL_ID" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='$GITHUB_REPO'" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### Binding (Allow Impersonation)

Here, an association is created between the [[#Create the Service Account|service account created earlier]] and the [[#Create the Workload Identity Provider|workload identity provider]]. When GitHub Actions presents a token to GCP, GCP will verify that the token comes from the expected repository, and if so, it will allow the token to impersonate the service account.

```bash
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/attribute.repository/${GITHUB_REPO}"
```

## Get the Provider ID

GitHub Actions will need to know the provider ID to be able to authenticate to GCP.

```bash
gcloud iam workload-identity-pools providers describe "$WIF_PROVIDER_ID" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="$WIF_POOL_ID" \
  --format="value(name)"
```

According to me, the provider ID should look like this: `projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/providers/${WIF_PROVIDER_ID}`

## Testing the Setup

```yaml
name: Deploy Spark Cluster

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  deploy-infra:
    runs-on: ubuntu-latest
    permissions:
      contents: 'read'
      id-token: 'write'

    steps:
      - uses: actions/checkout@v3

      - id: 'auth'
        name: 'Authenticate to GCP'
        uses: 'google-github-actions/auth@v1'
        with:
          workload_identity_provider: 'projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/providers/${WIF_PROVIDER_ID}'
          service_account: '${SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com'
```
