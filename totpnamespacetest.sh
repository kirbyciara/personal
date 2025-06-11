#!/usr/bin/env bash
# Script for testing TOTP in a namespace or TOTP in general but this is NOT for the secrets engine.
# Testing gitstream again


# Delete current /secret kv store
vault secrets disable secret

# Enable kv
vault secrets enable -version=2 -path=secret kv

# Save Secret in kv
vault kv put secret/foo mypwd=kirbysafe

# Enable user/pass auth method
 vault auth enable -namespace=totpnamespacetest userpass

# Log into namespace
vault login -namespace=totpnamespacetest

# Configure TOTP MFA
vault write sys/mfa/method/totp/my_totp2 \
    issuer=Vault \
    period=60 \
    key_size=30 \
    algorithm=SHA256 \
    digits=6

# Create Policy for the Secret to just access via MFA
vault policy write -namespace=totpnamespacetest ns-totp-policy -<<EOF
path "secret/foo" {
  capabilities = ["read"]
  mfa_methods  = ["my_totp"]
}

# namespace policy
path "sys/namespaces/*" {
capabilities = ["read"]
}
EOF

# Create a user in the userpass auth method
vault write -namespace=totpnamespacetest auth/userpass/users/testuser2 \
    password=testpassword2 \
    policies=ns-totp-policy

# Create a login token
 vault write -namespace=totpnamespacetest auth/userpass/login/testuser2 \
    password=testpassword2

# Create and save login token
TOKEN=$(vault write -namespace=totpnamespacetest auth/userpass/login/testuser2 password=testpassword2 | grep token | head -1 | xargs | cut -d" " -f2)

# Fetch entity ID from token
 vault token lookup $TOKEN

ENTITY_ID=$(vault token lookup $TOKEN | grep entity_id | xargs | cut -d" " -f2)

# Generate TOTP
vault write -namespace=totpnamespacetest sys/mfa/method/totp/my_totp2/admin-generate entity_id=$ENTITY_ID

# Logging into vault with testuser token
vault login $TOKEN

# Read the secret with  mfa flag
vault read -mfa my_totp:<put_six_digit_number_from_device_here!> secret/foo
