#!/bin/bash

set -e


echo '###############################################################################################'
echo '#       Generating Authentication Token                                                       #'
echo '###############################################################################################'

USERNAME=exampleuser
PASSWORD=$(docker exec -ti edgex-security-proxy-setup ./secrets-config proxy adduser --user "${USERNAME}" --tokenTTL 60 --jwtTTL 119m --useRootToken | jq -r '.password')

echo 'Fetching Vault Token from Hashicorp Vault Service'
VAULT_TOKEN=$(curl -ks "http://localhost:8200/v1/auth/userpass/login/${USERNAME}" -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')

echo 'Fetching ID Token on the basis of the Vault Token'
ID_TOKEN=$(curl -ks -H "Authorization: Bearer ${VAULT_TOKEN}" "http://localhost:8200/v1/identity/oidc/token/${USERNAME}" | jq -r '.data.token')

echo $ID_TOKEN
