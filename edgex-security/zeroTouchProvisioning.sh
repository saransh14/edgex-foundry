#!/bin/bash

set -x -e

echo '###############################################################################################'
echo '#      Service Config Parameters                                                              #'
echo '###############################################################################################'

METADATA_SVC_HOST=localhost
METADATA_SVC_PORT=59881
METADATA_SVC_VERSION_PREFIX=api/v3

METADATA_DEVICE_PROFILE_FILE=HVAC_deviceProfile.yaml
METADATA_DEVICE_FILE=HVAC_device.json
echo -e 'Configuration of service parameters completed successfully... \n\n'




echo '###############################################################################################'
echo '#       API Endpoint Details                                                                  #'
echo '###############################################################################################'

METADATA_GET_ALL_DEVICE_PROFILES_ENDPOINT=deviceprofile/all
METADATA_GET_ALL_DEVICES_ENDPOINT=device/all


METADATA_PROVISION_DEVICE_PROFILE_ENDPOINT=deviceprofile/uploadfile
METADATA_PROVISION_DEVICE_ENDPOINT=device


METADATA_DELETE_DEVICE_PROFILE_ENDPOINT=deviceprofile/name
METADATA_DELETE_DEVICE_ENDPOINT=device/name

echo -e 'Configuration of API Endpoints details completed successfully...\n\n'



echo '###############################################################################################'
echo '#       Generating Authentication Token                                                       #'
echo '###############################################################################################'

USERNAME=exampleuser
PASSWORD=$(docker exec -ti edgex-security-proxy-setup ./secrets-config proxy adduser --user "${USERNAME}" --tokenTTL 60 --jwtTTL 119m --useRootToken | jq -r '.password')

echo 'Fetching Vault Token from Hashicorp Vault Service'
VAULT_TOKEN=$(curl -ks "http://localhost:8200/v1/auth/userpass/login/${USERNAME}" -d "{\"password\":\"${PASSWORD}\"}" | jq -r '.auth.client_token')

echo 'Fetching ID Token on the basis of the Vault Token'
ID_TOKEN=$(curl -ks -H "Authorization: Bearer ${VAULT_TOKEN}" "http://localhost:8200/v1/identity/oidc/token/${USERNAME}" | jq -r '.data.token')


echo '###############################################################################################'
echo '#       Cleanup default deviceProfile and devices                                             #'
echo '###############################################################################################'

echo 'Fetching list of device profiles configured as default profiles on EdgeX startup...'
DEFAULT_DEVICE_PROFILES_LIST=$(curl -s -H "Authorization: Bearer ${ID_TOKEN}" -X GET http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_GET_ALL_DEVICE_PROFILES_ENDPOINT | jq -r '.profiles[].name')

echo -e 'Fetching list of default device profiles completed...\n'

echo 'Fetching list of devices configured as default devicess on EdgeX startup...'
DEFAULT_DEVICES_LIST=$(curl -s -H "Authorization: Bearer ${ID_TOKEN}" -X GET http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_GET_ALL_DEVICES_ENDPOINT | jq -r '.devices[].name')

echo -e 'Fetching list of default devices completed...\n'


echo 'Start Cleaning up default devices and device profiles...'
echo -e 'Initially clean devices followed by device profiles...\n'

for DEVICE_NAME in $DEFAULT_DEVICES_LIST
do
  curl -s -H "Authorization: Bearer ${ID_TOKEN}" -X DELETE http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_DELETE_DEVICE_ENDPOINT/$DEVICE_NAME >> /dev/null
done
echo 'Default devices deleted successfully...'


for DEVICE_PROFILE_NAME in $DEFAULT_DEVICE_PROFILES_LIST
do
  curl -s -H "Authorization: Bearer ${ID_TOKEN}" -X DELETE http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_DELETE_DEVICE_PROFILE_ENDPOINT/$DEVICE_PROFILE_NAME >> /dev/null
done
echo -e 'Default device profiles deleted successfully...\n\n'





echo '###############################################################################################'
echo '#       Starting Provisioning of device profile and devices                                   #'
echo '###############################################################################################'

echo 'Provisioning HVAC device profile...'
status_code=$(curl -s -X POST -H "Authorization: Bearer ${ID_TOKEN}" -H 'Content-Type: multipart/form-data' http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_PROVISION_DEVICE_PROFILE_ENDPOINT -F "file=@metadata/$METADATA_DEVICE_PROFILE_FILE" | jq -r .statusCode)
if [[ "$status_code" -eq 201 ]] ; then
  echo -e 'HVAC Device Profile provisioned successfully...\n'
else
  echo -e 'HVAC Device Profile provisioning failed...\n'
  exit 0
fi

sleep 5

echo 'Provisioning HVAC-1 device...'
status_code=$(curl -s -X POST -H "Authorization: Bearer ${ID_TOKEN}" -H 'Content-Type: application/json' http://$METADATA_SVC_HOST:$METADATA_SVC_PORT/$METADATA_SVC_VERSION_PREFIX/$METADATA_PROVISION_DEVICE_ENDPOINT -d@metadata/$METADATA_DEVICE_FILE | jq -r .[0].statusCode)
if [[ "$status_code" -eq 201 ]] ; then
  echo -e 'HVAC-1 Device provisioned successfully...\n'
else
  echo -e 'HVAC-1 Device provisioning failed...\n'
  exit 0
fi


