#!/bin/bash

# This script demonstrates how to set up a managed workload identity in Google Cloud.
# It creates a new project, a workload identity pool, a namespace, a managed identity,
# a service account, a certificate authority, and a virtual machine to test the setup.

# Set script to exit on any errors.
set -e

# --- Configuration Variables ---

# Generate a unique project ID
#export PROJECT_ID="mwlid-demo-$(date +%s)"
# While in Preview, use an existing project that has been whitelisted for MWLID - Request link: https://forms.gle/KC1Lq77gMn3kTtWDA
export PROJECT_ID="wif-okta"
# Create or use a separate project for your Certificate Authority Service
export CA_PROJECT_ID="jeansson-encryption"
# The billing account to which the new project will be linked.
# Replace with your billing account ID. e.g. 01A2B3-45C6D7-89E0F1
export BILLING_ACCOUNT="0196D1-C71CF0-AE83DC"
# The name of the workload identity pool.
export WORKLOAD_IDENTITY_POOL="mwlid-demo-pool-$(date +%s)"
# The location of the workload identity pool.
export WORKLOAD_IDENTITY_POOL_LOCATION="global"
# The mode of the workload identity pool.
export WORKLOAD_IDENTITY_POOL_MODE="TRUST_DOMAIN"
# The name of the namespace.
export NAMESPACE="managed-id-ns-demo"
# The name of the managed identity.
export MANAGED_IDENTITY="my-awesome-managed-id"
# The name of the service account for the VM.
export VM_SERVICE_ACCOUNT="demo-vm-sa"
# The region for the certificate authority.
export REGION="us-central1"
# The name of the root certificate authority pool.
export ROOT_CA_POOL="managed-id-ca-$(date +%s)"
# The name of the subordinate certificate authority pool.
export SUB_CA_POOL="managed-id-sub-ca-$(date +%s)"
# The name of the root certificate.
export ROOT_CERTIFICATE="managed-id-root"
# The name of the subordinate certificate.
export SUB_CERTIFICATE="managed-id-sub"
# The name of the virtual machine.
export VM_NAME="managed-id-vm-$(date +%s)"
# The zone for the virtual machine.
export ZONE="us-central1-f"
# The name of the virtual private cloud network.
export VPC_NETWORK="my-local-vpc"
# The name of the subnet.
export SUBNET="my-central1-subnet"
# The IP range for the subnet.
export SUBNET_RANGE="192.168.200.0/24"
# The user to grant access to the service account.
# Replace with your user email.
export CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# --- Script Execution ---

echo -e "\n--- Starting Managed Workload ID Demo Setup as user: ${CURRENT_USER} ---"

# 1. Create new projects if needed

echo -e "\n--- Step 1a: Validating Project ${PROJECT_ID} ---\n"
if ! gcloud projects describe ${PROJECT_ID} >/dev/null 2>&1; then
  echo -e "Project ${PROJECT_ID} does not exist. Creating it now..."
  gcloud projects create ${PROJECT_ID}
  # IMPORTANT: Replace 'BILLING_ACCOUNT_ID' with your actual billing account ID.
  gcloud billing projects link ${PROJECT_ID} --billing-account=${BILLING_ACCOUNT}
fi

echo -e "\n--- Step 1b: Validating Project ${CA_PROJECT_ID} ---\n"
if ! gcloud projects describe ${CA_PROJECT_ID} >/dev/null 2>&1; then
  echo -e "Project ${CA_PROJECT_ID} does not exist. Creating it now..."
  gcloud projects create ${CA_PROJECT_ID}
  # IMPORTANT: Replace 'BILLING_ACCOUNT_ID' with your actual billing account ID.
  gcloud billing projects link ${CA_PROJECT_ID} --billing-account=${BILLING_ACCOUNT}
fi

gcloud config set project "$PROJECT_ID"
echo -e "\n--- Projects $PROJECT_ID and $CA_PROJECT_ID have been configured. ---"

# 2. Enable required services
echo -e "\n--- Step 2: Enabling required services ---"
gcloud services enable iam.googleapis.com \
    privateca.googleapis.com \
    compute.googleapis.com \
    iamcredentials.googleapis.com \
    compute.googleapis.com \
    iap.googleapis.com --project=${PROJECT_ID}
gcloud services enable privateca.googleapis.com \
     --project=${CA_PROJECT_ID}    
echo -e "\n--- Services enabled. ---"

# 3. Create a workload identity pool
echo -e "\n--- Step 3: Creating a workload identity pool: $WORKLOAD_IDENTITY_POOL ---"
gcloud iam workload-identity-pools create "$WORKLOAD_IDENTITY_POOL" \
    --location="$WORKLOAD_IDENTITY_POOL_LOCATION" \
    --mode="$WORKLOAD_IDENTITY_POOL_MODE"
echo -e "\n--- Workload identity pool created. ---"

# 4. Create a namespace in the workload identity pool
echo -e "\n--- Step 4: Creating a namespace: $NAMESPACE ---"
gcloud iam workload-identity-pools namespaces create "$NAMESPACE" \
    --workload-identity-pool="$WORKLOAD_IDENTITY_POOL" \
    --location="$WORKLOAD_IDENTITY_POOL_LOCATION"
echo -e "\n--- Namespace created. ---"

# 5. Create a managed identity
echo -e "\n--- Step 5: Creating a managed identity: $MANAGED_IDENTITY ---"
gcloud iam workload-identity-pools managed-identities create "$MANAGED_IDENTITY" \
    --namespace="$NAMESPACE" \
    --workload-identity-pool="$WORKLOAD_IDENTITY_POOL" \
    --location="$WORKLOAD_IDENTITY_POOL_LOCATION"
echo -e "\n--- Managed identity created. ---"

# 6. Create a service account for the VM
if ! gcloud iam service-accounts describe ${VM_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com >/dev/null 2>&1; then
  echo -e "\n--- Step 6: Creating a service account for the VM: $VM_SERVICE_ACCOUNT ---"
  gcloud iam service-accounts create "$VM_SERVICE_ACCOUNT"
  echo -e "\n--- VM service account created. ---"
fi

# 7. Create the attestation policy file
echo -e "\n--- Step 7: Creating the attestation policy file ---"
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
cat > cloud_config/attPolicy.json << EOF
{
   "attestationRules": [
      {
         "googleCloudResource": "//compute.googleapis.com/projects/$PROJECT_NUMBER/type/Instance/attached_service_account.email/$VM_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com"
      }
   ]
}
EOF
echo -e "\n--- Attestation policy file created. ---"

# 8. Set the attestation rules for the managed identity
echo -e "\n--- Step 8: Setting the attestation rules for the managed identity ---"
gcloud iam workload-identity-pools managed-identities set-attestation-rules "$MANAGED_IDENTITY" \
    --namespace="$NAMESPACE" \
    --workload-identity-pool="$WORKLOAD_IDENTITY_POOL" \
    --policy-file=cloud_config/attPolicy.json \
    --location="$WORKLOAD_IDENTITY_POOL_LOCATION"
echo -e "\n--- Attestation rules set. ---"

# 9. Create a root certificate authority pool
echo -e "\n--- Step 9: Creating a root certificate authority pool: $ROOT_CA_POOL ---"
gcloud privateca pools create "$ROOT_CA_POOL" \
    --location="$REGION" \
    --tier=enterprise \
    --project=$CA_PROJECT_ID
echo -e "\n--- Root certificate authority pool created. ---"

# 10. Create a root certificate
echo -e "\n--- Step 10: Creating a root certificate: $ROOT_CERTIFICATE ---"
gcloud privateca roots create "$ROOT_CERTIFICATE" \
    --pool="$ROOT_CA_POOL" \
    --subject="CN=$ROOT_CERTIFICATE, O=example.io" \
    --key-algorithm="ec-p256-sha256" \
    --max-chain-length=1 \
    --location="$REGION" \
    --project=$CA_PROJECT_ID \
    --auto-enable
echo -e "\n--- Root certificate created. ---"

# 11. Create a subordinate certificate authority pool
echo -e "\n--- Step 11: Creating a subordinate certificate authority pool: $SUB_CA_POOL ---"
gcloud privateca pools create "$SUB_CA_POOL" \
    --location="$REGION" \
    --tier=devops \
    --project=$CA_PROJECT_ID
echo -e "\n--- Subordinate certificate authority pool created. ---"

# 12. Create a subordinate certificate
echo -e "\n--- Step 12: Creating a subordinate certificate: $SUB_CERTIFICATE ---"
gcloud privateca subordinates create "$SUB_CERTIFICATE" \
    --pool="$SUB_CA_POOL" \
    --location="$REGION" \
    --issuer-pool="$ROOT_CA_POOL" \
    --issuer-location="$REGION" \
    --subject="CN=$SUB_CERTIFICATE, O=example.io" \
    --key-algorithm="ec-p256-sha256" \
    --use-preset-profile=subordinate_mtls_pathlen_0 \
    --project=$CA_PROJECT_ID \
    --auto-enable
echo -e "\n--- Subordinate certificate created. ---"

# 13. Grant permissions to the workload identity pool to request certificates
echo -e "\n--- Step 13: Granting permissions to the workload identity pool ---"
gcloud privateca pools add-iam-policy-binding "$SUB_CA_POOL" \
    --project=$CA_PROJECT_ID \
    --location="$REGION" \
    --role=roles/privateca.workloadCertificateRequester \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/$WORKLOAD_IDENTITY_POOL_LOCATION/workloadIdentityPools/$WORKLOAD_IDENTITY_POOL/*"
gcloud privateca pools add-iam-policy-binding "$SUB_CA_POOL" \
    --project=$CA_PROJECT_ID \
    --location="$REGION" \
    --role=roles/privateca.poolReader \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/$WORKLOAD_IDENTITY_POOL_LOCATION/workloadIdentityPools/$WORKLOAD_IDENTITY_POOL/*"
echo -e "\n--- Permissions granted. ---"

# 14. Create the GCE issuance configuration file
echo -e "\n--- Step 14: Creating the GCE issuance configuration file ---"
cat > cloud_config/gce-issuance-config << EOF
{
  "primary_certificate_authority_config": {
    "certificate_authority_config": {
      "ca_pool": "projects/$CA_PROJECT_ID/locations/$REGION/caPools/$SUB_CA_POOL"
    }
  },
  "key_algorithm": "rsa-4096",
  "workload_certificate_lifetime_seconds": 3600,
  "rotation_window_percentage": 50
}
EOF
echo -e "\n--- GCE issuance configuration file created. ---"

# 15. Create the trust configuration file
echo -e "\n--- Step 15: Creating the trust configuration file ---"
gcloud privateca subordinates describe "$SUB_CERTIFICATE" --location="$REGION" --pool="$SUB_CA_POOL" --project="$CA_PROJECT_ID" --format="value(pemCaCertificates)" > cloud_config/trust-anchor.pem
TRUST_ANCHOR_PEM=$(cat cloud_config/trust-anchor.pem | sed 's/^[ ]*//g' | sed -z '$ s/\n$//' | tr '\n' '\n' | sed 's/$/\\n/g' | sed '$ s/\\n$//')
cat > cloud_config/trust-config.json << EOF
{
  "$WORKLOAD_IDENTITY_POOL.$WORKLOAD_IDENTITY_POOL_LOCATION.$PROJECT_NUMBER.workload.id.goog": {
    "trust_anchors": [
      {
        "pem_certificate": "$TRUST_ANCHOR_PEM"
      }
    ]
  }
}
EOF
echo -e "\n--- Trust configuration file created. ---"

# 16. Create the CONFIGS.json file
echo -e "\n--- Step 16: Creating the CONFIGS.json file ---"
cat > cloud_config/CONFIGS.json << EOF
{
  "wc.compute.googleapis.com": {
     "entries": {
        "certificate-issuance-config": {
           "primary_certificate_authority_config": {
              "certificate_authority_config": {
                 "ca_pool": "projects/$CA_PROJECT_ID/locations/$REGION/caPools/$SUB_CA_POOL"
              }
           },
           "key_algorithm": "rsa-4096"
        },
        "trust-config": {
           "$WORKLOAD_IDENTITY_POOL.$WORKLOAD_IDENTITY_POOL_LOCATION.$PROJECT_NUMBER.workload.id.goog": {
               "trust_anchors": [{
                  "ca_pool": "projects/$CA_PROJECT_ID/locations/$REGION/caPools/$SUB_CA_POOL"
                }]
           }
     }
  }
  },
  "iam.googleapis.com": {
     "entries": {
        "workload-identity": "spiffe://$WORKLOAD_IDENTITY_POOL.$WORKLOAD_IDENTITY_POOL_LOCATION.$PROJECT_NUMBER.workload.id.goog/ns/$NAMESPACE/sa/$MANAGED_IDENTITY"
     }
  }
}
EOF
echo -e "\n--- CONFIGS.json file created. ---"

# 17. Create a VPC network, subnet and configuring a firewall rule for IAP 
echo -e "\n--- Step 17: Validating VPC network and subnet ---"

# Validate VPC
if ! gcloud compute networks describe ${VPC_NETWORK} --project=${PROJECT_ID} >/dev/null 2>&1; then
  echo -e "VPC ${VPC_NETWORK} not found. Creating it now..."
  gcloud compute networks create ${VPC_NETWORK} --project=${PROJECT_ID} --subnet-mode=custom
  echo -e "\n--- VPC network. ---"
fi

if ! gcloud compute networks subnets describe ${SUBNET} --project=${PROJECT_ID} --region=${REGION} >/dev/null 2>&1; then
  echo -e "Subnet ${SUBNET} not found. Creating it now..."
  gcloud compute networks subnets create ${SUBNET} --project=${PROJECT_ID} --network=${VPC_NETWORK} --range=${SUBNET_RANGE} --region=${REGION}
  echo -e "\n--- VPC subnet created. ---"
fi

if ! gcloud compute firewall-rules describe allow-ssh-form-iap --project=${PROJECT_ID} >/dev/null 2>&1; then
# Adding firewall rule for IAP access to VM
echo -e "Adding firewall rule for IAP SSH access to VM...\n"
gcloud compute firewall-rules create allow-ssh-form-iap --network ${VPC_NETWORK} --direction=INGRESS --allow tcp:22 --source-ranges 35.235.240.0/20 --project=${PROJECT_ID}
fi

# 18. Grant the user the Service Account User role
echo -e "\n--- Step 18: Granting the user the Service Account User role ---"
gcloud iam service-accounts add-iam-policy-binding "$VM_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --member="user:$CURRENT_USER" \
    --role=roles/iam.serviceAccountUser \
    --project="$PROJECT_ID"
echo -e "\n--- Service Account User role granted. ---"

# 19. Create the VM
echo -e "\n--- Step 19: Creating the VM: $VM_NAME ---"
gcloud beta compute instances create "$VM_NAME" \
    --zone="$ZONE" \
    --service-account "$VM_SERVICE_ACCOUNT@$PROJECT_ID.iam.gserviceaccount.com" \
    --metadata enable-workload-certificate=true \
    --partner-metadata-from-file cloud_config/CONFIGS.json \
    --network-interface="no-address,network=$VPC_NETWORK,subnet=$SUBNET" \
    --shielded-secure-boot \
    --shielded-vtpm \
    --project="$PROJECT_ID"
echo -e "\n--- VM created. ---"

# 20. Grant IAP access to VM
echo -e "--- Step 20: Granting IAP access to user. ---\n"
gcloud compute instances add-iam-policy-binding ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID} --member=user:${CURRENT_USER} --role=roles/compute.instanceAdmin.v1
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member=user:${CURRENT_USER} --role=roles/iap.tunnelResourceAccessor --condition=None


# Give the VM time to boot
echo -e "\nWaiting for VM to boot...\n"
sleep 30

# 21. Print the SPIFFE credentials from the VM by curl-ing the Instance metadata
echo -e "\n\n--- Step 21: Conect to your VM using SSH and inspect the SPIFFE credentials ---\n"
echo -e "\n *** SSH into your VM and run the following command: ***\n"
echo -e "curl -s "http://metadata.google.internal/computeMetadata/v1/instance/gce-workload-certificates/workload-identities" -H "Metadata-Flavor: Google"\n"

echo -e "\n\n--- Managed Workload ID Demo Setup Complete ---"
echo -e "\n\n*** Your VM will have the SPIFFE credentials automatically loaded and updated to:\n /var/run/secrets/workload-spiffe-credentials from instance metadata ***"
echo -e "\n*** Your SPIFFE ID will be:\n spiffe://$WORKLOAD_IDENTITY_POOL.$WORKLOAD_IDENTITY_POOL_LOCATION.$PROJECT_NUMBER.workload.id.goog/ns/$NAMESPACE/sa/$MANAGED_IDENTITY ***"