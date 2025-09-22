# GCP Managed Workload Identity Demo Setup

This document provides an overview of Google Cloud's Managed Workload Identity and explains how to use the provided shell script to set up a demonstration environment.

**DISCLAIMER 1:** This service is currently in Preview and requires project allow listing before testing. Apply Here: https://forms.gle/KC1Lq77gMn3kTtWDA 
While MWLID is in Preview, be sure to use an existing project that has been whitelisted when running the script.

**DISCLAIMER 2:** This script is intended for demonstration and educational purposes only. It is **NOT** recommended for production use.

## What is GCP Managed Workload Identity?

Managed Workload Identity (https://cloud.google.com/iam/docs/managed-workload-identity) lets you bind strongly attested identities to your Google Kubernetes Engine (GKE) and Compute Engine workloads.

Google Cloud provisions X.509 credentials and trust anchors that are issued from Certificate Authority Service. The credentials and trust anchors can be used to reliably authenticate your workload with other workloads through mutual TLS (mTLS) authentication.

Managed workload identities for GKE is available in Preview. Managed workload identities for Compute Engine is available in Preview, by request. Request access to the managed workload identities for Compute Engine Preview here: https://forms.gle/KC1Lq77gMn3kTtWDA 

It is based on the [SPIFFE (Secure Production Identity Framework for Everyone)](https://spiffe.io/) standard, providing a consistent and secure way to establish trust between your workloads and Google Cloud.

For more detailed information, please refer to the official Google Cloud documentation: [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation).


## About This Demo Script (`gcloud_managed_id_demo_setup-v2.sh`)

This shell script (`gcloud_managed_id_demo_setup-v2.sh`) automates the setup of a complete Managed Workload Identity demonstration environment in Google Cloud.

### What the Script Does

The script performs the following actions:

1.  **Project Setup:** Validates or creates two Google Cloud projects: one for the demo resources and one for the Certificate Authority Service.
2.  **Enable APIs:** Enables all necessary APIs for the demo (IAM, Private CA, Compute Engine, etc.) in both projects.
3.  **Workload Identity Pool:** Creates a Workload Identity Pool and a Namespace.
4.  **Managed Identity:** Creates a Managed Identity within the namespace.
5.  **Service Account:** Creates a service account that the demo VM will use.
6.  **Attestation Policy:** Defines and applies a policy that specifies which workloads are allowed to impersonate the managed identity.
7.  **Certificate Authority (CA):** Sets up a root and subordinate Certificate Authority using Google Cloud Private CA to issue certificates for the workload.
8.  **Permissions:** Grants the necessary IAM permissions for the Workload Identity Pool to request certificates and for the user to access the service account and VM.
9.  **Configuration Files:** Generates the required configuration files (`attPolicy.json`, `gce-issuance-config`, `trust-config.json`, `CONFIGS.json`).
10. **Networking:** Creates a VPC, a subnet, and a firewall rule to allow SSH access via IAP.
11. **Virtual Machine (VM):** Creates a Google Compute Engine VM configured to use Managed Workload Identity.
12. **IAP Access:** Grants the user IAP-secured Tunnel User role to allow SSH access to the new VM.

### How to Use

1.  **Prerequisites:**
    *   Google Cloud SDK (`gcloud`) installed and authenticated.
    *   A valid Google Cloud Billing Account ID.
2.  **Configuration:**
    *   Open the `gcloud_managed_id_demo_setup-v2.sh` script.
    *   Update the `BILLING_ACCOUNT` variable with your billing account ID.
3.  **Execution:**
    *   Run the script from your terminal:
        ```bash
        bash gcloud_managed_id_demo_setup-v2.sh
        ```

The script will then provision all the necessary resources. Upon completion, it will prompt you to SSH into the created VM and print the SPIFFE credentials, demonstrating that the setup was successful.
