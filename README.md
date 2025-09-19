# GCP Managed Workload Identity Demo Setup

This document provides an overview of Google Cloud's Managed Workload Identity and explains how to use the provided shell script to set up a demonstration environment.

**DISCLAIMER:** This script is intended for demonstration and educational purposes only. It is **NOT** recommended for production use.

## What is GCP Managed Workload Identity?

Managed Workload Identity is a feature in Google Cloud that allows you to securely authenticate and access Google Cloud services from workloads running outside of Google Cloud (e.g., on-premises, in other public clouds like AWS or Azure) without needing to manage and secure service account keys.

It is based on the [SPIFFE (Secure Production Identity Framework for Everyone)](https://spiffe.io/) standard, providing a consistent and secure way to establish trust between your workloads and Google Cloud.

For more detailed information, please refer to the official Google Cloud documentation: [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation).

### Benefits

*   **Improved Security:** Eliminates the need for long-lived service account keys, which reduces the risk of key compromise. Credentials are short-lived and automatically rotated.
*   **Simplified Credential Management:** Automates the process of obtaining and managing credentials for your workloads.
*   **Interoperability:** Based on open standards like SPIFFE and OpenID Connect (OIDC), allowing for integration with a wide range of identity providers.

### Use Cases

*   **Hybrid and Multi-Cloud Deployments:** Authenticate applications running on-premises or in other cloud environments to access Google Cloud services.
*   **CI/CD Pipelines:** Allow your CI/CD jobs (e.g., running on Jenkins or GitLab) to securely access Google Cloud resources.
*   **Securely connecting to Google Cloud services from third-party platforms.**

## About This Demo Script (`gcloud_managed_id_demo_setup-v2.sh`)

This shell script (`gcloud_managed_id_demo_setup-v2.sh`) automates the setup of a complete Managed Workload Identity demonstration environment in Google Cloud.

### What the Script Does

The script performs the following actions:

1.  **Project Setup:** Creates a new Google Cloud project.
2.  **Enable APIs:** Enables all necessary APIs for the demo (IAM, Private CA, Compute Engine, etc.).
3.  **Workload Identity Pool:** Creates a Workload Identity Pool and a Namespace.
4.  **Managed Identity:** Creates a Managed Identity within the namespace.
5.  **Service Account:** Creates a service account that the demo VM will use.
6.  **Attestation Policy:** Defines a policy that specifies which workloads are allowed to impersonate the managed identity.
7.  **Certificate Authority (CA):** Sets up a root and subordinate Certificate Authority using Google Cloud Private CA to issue certificates for the workload.
8.  **Permissions:** Grants the necessary IAM permissions for the Workload Identity Pool to request certificates.
9.  **Configuration Files:** Generates the required configuration files (`attPolicy.json`, `gce-issuance-config`, `trust-config.json`, `CONFIGS.json`).
10. **Networking:** Creates a VPC and a subnet for the demo VM.
11. **Virtual Machine (VM):** Creates a Google Compute Engine VM configured to use Managed Workload Identity.
12. **Verification:** Connects to the newly created VM via SSH and displays the automatically mounted SPIFFE credentials.

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

The script will then provision all the necessary resources. Upon completion, it will SSH into the created VM and print the SPIFFE credentials, demonstrating that the setup was successful.
