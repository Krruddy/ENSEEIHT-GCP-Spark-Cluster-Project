# ENSEEIHT-GCP-Spark-Cluster-Project

This project focuses on automating the deployment of an Apache Spark cluster using Terraform and Ansible on Google Cloud Platform (GCP).

The deployment of the Spark cluster will be done by following the CI/CD pipeline through GitHub Actions.

# Dependencies

Dependencies:

- [Terraform](https://developer.hashicorp.com/terraform)
- [GCLoud](https://docs.cloud.google.com/sdk/docs/install-sdk)

# Infrastructure

## Network Architecture

We create a Virtual Private Cloud (VPC) to host our Spark cluster. The VPC will contain the two subnets:

- `public_subnet`: Hosts the edge node which allows SSH access to the cluster.
- `private_subnet`: Hosts the Spark master and worker nodes.

The VPC's firewall rules will be configured to allow necessary traffic:

- **Cluster Chatter**: Allow all communication between the nodes in the VPC on all ports (might be too permissive, and might be changed later).
- **SSH Access**: Allow SSH access (port 22) to the bastion host from the internet.

A router will also be created on the VPC to allow outbound internet access for all nodes through NAT.

> [!NOTE]
> The configuration which allows the edge node to be accessed from the internet is done when instantiating it, not during the configuration of the VPC.

## Virtual Machines

Three types of VMs will be used in this project:

- **Edge Node**: Node used to access the cluster from the internet.
- **Spark Master**: Node that manages the Spark cluster.
- **Spark Workers**: Nodes that perform the actual data processing.

The [recommended hardware specifications](https://spark.apache.org/docs/latest/hardware-provisioning.html) are quite high. In this project, we will underprovision the hardware to save costs, and upgrade if necessary.

Because of the nature of this project (learning purpose, not production), we will limit ourselves to using [E2 machine series](https://docs.cloud.google.com/compute/docs/general-purpose-machines#e2_machine_types).

All the VMs will use the latest [Debian](https://docs.cloud.google.com/compute/docs/images/os-details#debian) image available on GCP.

When it comes to the [disk types](https://docs.cloud.google.com/compute/docs/general-purpose-machines#e2_disks), we will first attempt to use the cheapest option, which is the `pd-standard` (HDD). If the performance is not satisfactory, we will switch to `pd-balanced` (SSD),  which is more balanced.

The edge node doesn't need to be very powerful since it is only used for accessing the cluster and submitting jobs, so we will use an [e2-micro](https://docs.cloud.google.com/compute/docs/general-purpose-machines#sharedcore) instance type. It's boot disk will be 15GB in size.

The Spark master and worker nodes need more resources, so they will use the [e2-small](https://docs.cloud.google.com/compute/docs/general-purpose-machines#sharedcore) instance types as a starting point. Their boot disks will be 20GB in size, and additional data disks of 10GB will be attached to each worker for Spark storage.

|              |   `edge`   |  `master`  |  `worker`  |
| :----------: | :--------: | :--------: | :--------: |
| Machine Type | `e2-micro` | `e2-small` | `e2-small` |
|  Boot Disk   |     15     |     20     |     20     |
|  Spark Disk  |     -      |     -      |     10     |

# Configuration

The following variables are used throughout the setup process. Place them in your shell environment or in a script to reuse them easily.

```bash
PROJECT_ID="enseeiht-spark-lab"
PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

REGION="europe-west1"
TF_STATE_BUCKET="spark-lab-tfstate"

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

Later, `terraform init` and `terraform apply` will be used locally as part of the development process. Terraform will use the credentials from `gcloud` to authenticate to GCP. For that reason, we need to make sure that the account used by `gcloud` has the same IAM permissions as the service account created for GitHub Actions.

If the account used by `gcloud` is the account that was used to create the project, it should already have the necessary permissions. That is because the account that creates a project is automatically granted the `Owner` role on that project.

Otherwise, the necessary roles must be granted to the account used by `gcloud` (replace `<YOUR_EMAIL>` with the email of that account):

```bash
# Grant Compute Admin role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/compute.admin"

# Grant Storage Admin role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/storage.admin"

# Grant Service Account User role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="user:<YOUR_EMAIL>" \
  --role="roles/iam.serviceAccountUser"
```

> [!NOTE]
> You can check which account is currently used by `gcloud` by running `gcloud auth list`.

Once the user has the necessary permissions, run the following command to set up Application Default Credentials (ADC) e.g., allowing Terraform to authenticate to GCP ([1](https://docs.cloud.google.com/sdk/gcloud/reference/alpha/auth/application-default/login)):

```bash
gcloud auth application-default login
```

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

According to me, the provider ID should look like this:

```bash
projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${WIF_POOL_ID}/providers/${WIF_PROVIDER_ID}
```

## Testing the Setup

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

env:
  PROJECT_ID: #'enseeiht-spark-lab' 
  LOCATION: 'europe-west1'
  PROJECT_NUMBER: #'177424230750'
  SERVICE_ACCOUNT_ID: #'github-actions-sa'
  SERVICE_ACCOUNT_EMAIL: '${{ env.SERVICE_ACCOUNT_ID }}@${{ env.PROJECT_ID }}.iam.gserviceaccount.com'
  WORKLOAD_IDENTITY_POOL_ID: #'github-pool'
  WORKLOAD_IDENTITY_PROVIDER_ID: #'github-provider'
  WORKLOAD_IDENTITY_PROVIDER: 'projects/${{ env.PROJECT_NUMBER }}/locations/global/workloadIdentityPools/${{ env.WORKLOAD_IDENTITY_POOL_ID }}/providers/${{ env.WORKLOAD_IDENTITY_PROVIDER_ID }}'

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
          workload_identity_provider: '${{ env.WORKLOAD_IDENTITY_PROVIDER }}'
          service_account: '${SA_ID}@${PROJECT_ID}.iam.gserviceaccount.com'
```

# Terraform State (Memory Bucket)

The memory of Terraform, e.g. the state of the infrastructure (`terraform.tfstate`) , will be stored in a [GCS bucket](https://docs.cloud.google.com/storage/docs/json_api/v1/buckets).

The decision of storing Terraforms state in a GCS bucket is made to:

- Prevent two pipelines from updating the infrastructure at the same time which could corrupt it (lock support).
- Keep track of the state of the infrastructure over time (versioning support).
- Simultaneous read access from multiple actors.

Since it is the Terraform state, Terroform can't create it, because the state needs to be available for Terraform to run. It will be created manually using the following commands:

```bash
gcloud storage buckets create "gs://${TF_STATE_BUCKET}" \
  --project="$PROJECT_ID" \
  --location="$REGION" \
  --uniform-bucket-level-access
# Enable Versioning
gcloud storage buckets update "gs://${TF_STATE_BUCKET}" \
  --versioning
```

- `--uniform-bucket-level-access`: Permissions are managed using IAM only, rather than a combination of IAM and ACLs.
- `--versioning`: When a file is overwritten in this bucket, GCP keeps a copy of the old version instead of deleting it ([1](https://docs.cloud.google.com/storage/docs/using-object-versioning#whats_next)).

# Terraform

To make the Terraform code more readable and maintainable, it is split into multiple files:

- `main.tf`: Defines the required Terraform providers and their versions for the project.
- `providers.tf`: Configures the Google Cloud provider with project-specific settings like project ID and default region/zone.
- `variables.tf`: Declares all input variables (like `project_id`, `worker_count`) and local values used throughout the configuration.
- `network.tf`: Defines all networking resources, including the VPC, subnets, firewall rules, and the Cloud NAT gateway.
- `compute.tf`: Defines all virtual machine instances (edge, master, workers) and their attached data disks.
- `backend.tf`: Configures the GCS backend for storing the Terraform state file remotely.

First, we use the following command to verify whether the configuration is syntactically valid and internally consistent (regardless of variables or existing state) ([1](https://developer.hashicorp.com/terraform/cli/commands/validate)):

```bash
terraform -chdir=./terraform validate
```

> [!WARNING]
> The command will fail if the provider is not yet installed. In that case, follow the next step to install the provider, then run the validate command again.

The following step will:

- Initialize the backend (in `backend.tf`).
- Download and install the required provider plugins (in `main.tf`).

Run the following command ([1](https://developer.hashicorp.com/terraform/cli/commands/init)):

```bash
terraform -chdir=./terraform init
```

The following command creates an execution plan, which lets you preview the changes that Terraform plans to make to your infrastructure ([1](https://developer.hashicorp.com/terraform/cli/commands/plan)):

```bash
terraform -chdir=./terraform plan
```

> [!WARNING]
> Terraform will fetch the public SSH key with the path `~/.ssh/id_ed25519.pub`. Make sure that this file exists (find [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) details on how to generate an SSH key).

## Compute

The NAT is configured ...

## Terraform State (Bucket)

## Outputs