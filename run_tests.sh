#!/usr/bin/env bash
docker rm -f vaultex-vault 2>/dev/null

export VAULT_ADDR=http://127.0.0.1:8290
export VAULT_ROOT_TOKEN=46eaf643-283a-6af9-4c9a-836914d1f7a6
export TOKEN_TTL=3600

# start vault dev server
docker run --name vaultex-vault -e VAULT_DEV_ROOT_TOKEN_ID=${VAULT_ROOT_TOKEN} -p 8290:8200 -d vault:latest
export VAULT_TOKEN=${VAULT_ROOT_TOKEN}

# Prepare vault setup for tests

## Policy
# try again if it fails as vault takes some time to be up
while true; do
    vault policy-write test-policy test/policy.hcl 2>/dev/null
    if [ $? -eq 0 ]; then
	break
    fi
    sleep 0.5
done

set -e
# re-enable the old storage backend
vault secrets enable generic

## Add data
vault write generic/allowed/read/valid value=bar
vault write generic/forbidden/read/valid value=flip

vault kv put secret/allowed/read/valid value=bar
vault kv put secret/forbidden/read/valid value=flip

## Setup user pass auth
export TEST_USER=twist
export TEST_PASSWORD=nuggy

vault auth enable userpass
vault write auth/userpass/users/${TEST_USER} \
    password=${TEST_PASSWORD} \
    policies=test-policy

## Setup app-id auth
vault auth enable app-id
vault write auth/app-id/map/app-id/valid-app-id value=test-policy
vault write auth/app-id/map/user-id/valid-user-id value=valid-app-id
export TEST_APP_ID=valid-app-id
export TEST_USER_ID=valid-user-id


## Setup token auth
vault write auth/token/roles/test_role period="${TOKEN_TTL}" allowed_policies=test-policy
export VAULT_NEW_TOKEN=`vault token-create -format=json -role test_role | jq -r ".auth.client_token"`
export VAULT_TOKEN=${VAULT_NEW_TOKEN}

echo "--------------------------------------------------------------------------------"
echo "VAULT_ROOT_TOKEN=${VAULT_ROOT_TOKEN}"
echo "VAULT_NEW_TOKEN=${VAULT_NEW_TOKEN}"

## Run the tests
mix test

docker rm -f vaultex-vault
