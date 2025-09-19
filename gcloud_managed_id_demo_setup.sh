### Managed Workload ID demo config ###
# https://cloud.google.com/iam/docs/create-managed-workload-identities
# https://cloud.google.com/compute/docs/access/authenticate-workloads-over-mtls#enable-workload-id-vms 
gcloud config set project wif-okta
gcloud iam workload-identity-pools create managed-workload-id-demo --location=global --mode="TRUST_DOMAIN"
gcloud iam workload-identity-pools namespaces create managed-id-ns-demo     --workload-identity-pool="managed-workload-id-demo"     --location="global"
gcloud iam workload-identity-pools managed-identities create my-demo-managed-id     --namespace="managed-id-ns-demo"     --workload-identity-pool="managed-workload-id-demo"     --location="global"
gcloud iam service-accounts create my-managed-id-vm-sa
gcloud iam workload-identity-pools describe managed-workload-id-demo     --location="global"
gcloud iam service-accounts describe my-demo-managed-id
gcloud iam service-accounts describe my-managed-id-vm-sa
gcloud iam service-accounts describe my-managed-id-vm-sa@wif-okta.iam.gserviceaccount.com
mkdir managed-workload-id-demo
cd managed-workload-id-demo/

cat > attPolicy.json << EOF
{
   "attestationRules": [
      {
         "googleCloudResource": "//compute.googleapis.com/projects/347864090333/type/Instance/attached_service_account.email/my-managed-id-vm-sa@wif-okta.iam.gserviceaccount.com"
      }
   ],
}
EOF

gcloud iam workload-identity-pools managed-identities set-attestation-rules my-demo-managed-id    --namespace=managed-id-ns-demo    --workload-identity-pool=managed-workload-id-demo    --policy-file=attPolicy.json    --location=global
gcloud iam workload-identity-pools managed-identities add-attestation-rule my-demo-managed-id    --namespace=managed-id-ns-demo    --workload-identity-pool=managed-workload-id-demo    --google-cloud-resource='//compute.googleapis.com/projects/347864090333/type/Instance/attached_service_account.uid/108040501264128932171'    --location=global

gcloud config set project jeansson-encryption
gcloud privateca pools create managed-id-ca    --location=us-central1    --tier=enterprise
gcloud privateca roots create managed-id-root    --pool=managed-id-ca    --subject "CN=managed-id-root, O=example.io"    --key-algorithm="ec-p256-sha256"    --max-chain-length=1    --location=us-central1
gcloud privateca pools create managed-id-sub-ca    --location=us-central1    --tier=devops
gcloud privateca subordinates create managed-id-sub    --pool=managed-id-sub-ca    --location=us-central1    --issuer-pool=managed-id-ca    --issuer-location=us-central1    --subject="CN=managed-id-sub, O=example.io"    --key-algorithm="ec-p256-sha256"    --use-preset-profile=subordinate_mtls_pathlen_0
gcloud privateca pools add-iam-policy-binding managed-id-sub-ca  --location=us-central1  --role=roles/privateca.workloadCertificateRequester  --member="principalSet://iam.googleapis.com/projects/347864090333/locations/global/workloadIdentityPools/managed-workload-id-demo/*"
gcloud privateca pools add-iam-policy-binding managed-id-sub-ca  --location=us-central1  --role=roles/privateca.poolReader  --member="principalSet://iam.googleapis.com/projects/347864090333/locations/global/workloadIdentityPools/managed-workload-id-demo/*"

cat > gce-issuance-config << EOF
{
  "primary_certificate_authority_config": {
    "certificate_authority_config": {
      "ca_pool": "projects/jeansson-encryption/locations/us-central1/caPools/managed-id-sub-ca"
    }
  },
  "key_algorithm": "rsa-4096",
  "workload_certificate_lifetime_seconds": 3600,
  "rotation_window_percentage": 50
}
EOF

gcloud privateca subordinates describe managed-id-sub --location=us-central1 --pool=managed-id-sub-ca --project=jeansson-encryption --format="value(pemCaCertificates) >> trust-anchor.pem"
# export TRUST_ANCHOR=$(gcloud privateca subordinates describe managed-id-sub --location=us-central1 --pool=managed-id-sub-ca --project=jeansson-encryption --format="value(pemCaCertificates))
cat trust-anchor.pem | sed 's/^[ ]*//g' | sed -z '$ s/\n$//' | tr '\n' $ | sed 's/\$/\\n/g' >> trust-string
cat > trust-config.json << EOF
{
  "managed-workload-id-demo.global.347864090333.workload.id.goog": {
    "trust_anchors": [
      {
        "ca_pool": "projects/jeansson-encryption/locations/us-central1/caPools/managed-id-sub-ca"
      },
      {
        "pem_certificate": "-----BEGIN CERTIFICATE-----\nMIIC/TCCAqOgAwIBAgIUAJZI4SXH3Kn8PS1gjSfB9cI7iHAwCgYIKoZIzj0EAwIw\nLzETMBEGA1UEChMKZXhhbXBsZS5pbzEYMBYGA1UEAxMPbWFuYWdlZC1pZC1yb290\nMB4XDTI1MDgyMjAwNTY1NloXDTI4MDgyMTE4MjMxM1owLjETMBEGA1UEChMKZXhh\nbXBsZS5pbzEXMBUGA1UEAxMObWFuYWdlZC1pZC1zdWIwWTATBgcqhkjOPQIBBggq\nhkjOPQMBBwNCAAToYQGmoaRmwhNQ8YimEfub3k+MbgFCFxXP2uMJ4pxAmVY3Y1vt\nKmcTj8H7l2aAvhjtraXfOj6O7LVKeKagBsQPo4IBnDCCAZgwDgYDVR0PAQH/BAQD\nAgEGMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjASBgNVHRMBAf8ECDAG\nAQH/AgEAMB0GA1UdDgQWBBQtp09TyPZEc9kbg4K6k7z+kJSaUDAfBgNVHSMEGDAW\ngBRSY0ZIaHJFxmxo3xvnOoRajnaayDCBjQYIKwYBBQUHAQEEgYAwfjB8BggrBgEF\nBQcwAoZwaHR0cDovL3ByaXZhdGVjYS1jb250ZW50LTY4ZDE1OTg3LTAwMDAtMjcy\nYi05NWQwLWI4ZGIzOGY0NTZmMi5zdG9yYWdlLmdvb2dsZWFwaXMuY29tL2I0YmQ2\nODg4OWZjMDY1ZWY1ZGJmL2NhLmNydDCBggYDVR0fBHsweTB3oHWgc4ZxaHR0cDov\nL3ByaXZhdGVjYS1jb250ZW50LTY4ZDE1OTg3LTAwMDAtMjcyYi05NWQwLWI4ZGIz\nOGY0NTZmMi5zdG9yYWdlLmdvb2dsZWFwaXMuY29tL2I0YmQ2ODg4OWZjMDY1ZWY1\nZGJmL2NybC5jcmwwCgYIKoZIzj0EAwIDSAAwRQIgb86tAaCY7gTcLrXIOXBHXKef\nYf7GosIJQi+6q1eSV2UCIQD6rLSJ2ytCmuVf4YyrDuwQ0Ns9nzkmbqnolQnd2WpM\nWg==\n-----END CERTIFICATE-----"
      }
    ]
  }
}
EOF
cat > CONFIGS.json << EOF
{
  "wc.compute.googleapis.com": {
     "entries": {
        "certificate-issuance-config": {
           "primary_certificate_authority_config": {
              "certificate_authority_config": {
                 "ca_pool": "projects/jeansson-encryption/locations/us-central1/caPools/managed-id-sub-ca"
              }
           },
           "key_algorithm": "rsa-4096"
        },
        "trust-config": {
           "managed-workload-id-demo.global.347864090333.workload.id.goog": {
               "trust_anchors": [{
                  "ca_pool": "projects/jeansson-encryption/locations/us-central1/caPools/managed-id-sub-ca"
                }]
           }
     }
  }
  },
  "iam.googleapis.com": {
     "entries": {
        "workload-identity": "spiffe://managed-workload-id-demo.global.347864090333.workload.id.goog/ns/managed-id-ns-demo/sa/my-demo-managed-id"
     }
  }
}
EOF

gcloud compute networks create my-local-vpc --subnet-mode=custom --project=wif-okta
gcloud compute networks subnets create my-central1-subnet --region=us-central1 --range=192.168.10.0/24 --enable-private-ip-google-access --network=my-local-vpc --project=wif-okta
gcloud iam service-accounts add-iam-policy-binding my-managed-id-vm-sa@wif-okta.iam.gserviceaccount.com --member=user:admin@jeansson.altostrat.com --role=roles/iam.serviceAccountUser --project=wif-okta
gcloud beta compute instances create managed-id-vm    --zone=us-central1-a    --service-account my-managed-id-vm-sa@wif-okta.iam.gserviceaccount.com    --metadata enable-workload-certificate=true    --partner-metadata-from-file CONFIGS.json --network-interface=no-address,network=my-local-vpc,subnet=my-central1-subnet --shielded-secure-boot --shielded-vtpm --project=wif-okta

# Your VM will have the SPIFFE credentials automatically loaded and updated to /var/run/secrets/workload-spiffe-credentials from instance metadata
# Your SPIFFE ID will be: spiffe://managed-workload-id-demo.global.347864090333.workload.id.goog/ns/managed-id-ns-demo/sa/my-demo-managed-id