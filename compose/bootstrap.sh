#!/usr/bin/env bash

# creates a Keycloak realm, client and user to be used with the auth proxy

set -e

# default credentials
USERNAME="${KEYCLOAK_USER:-admin}"
PASSWORD="${KEYCLOAK_PASSWORD:-admin}"
KEYCLOAK_INSTANCE="${KEYCLOAK_INSTANCE:-localhost:8080}"
REALM="${KEYCLOAK_REALM:-auth-test}"
CLIENT_NAME="${CLIENT_NAME:-httpbin-auth}"
KEYCLOAK_REALM_CONFIG="${KEYCLOAK_REALM_CONFIG:-/compose/auth-test-realm.json}"

# download jq to make it easier to parse the JSON returned from Keycloak
COMPOSE_DIR="/compose"
PATH=${COMPOSE_DIR}:${PATH}
curl -s -L -o "${COMPOSE_DIR}/jq" https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && chmod +x "${COMPOSE_DIR}/jq"

# wait for Keycloak to be ready
while [[ $(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 http://${KEYCLOAK_INSTANCE}/auth/realms/master) -ne 200 ]]; do
  echo 'Keycloak not ready yet, sleeping for 10 seconds...'
  sleep 10
done

# get access token from master realm
export TOKEN=$(curl -s -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}" \
  -d 'grant_type=password' \
  -d 'scope=openid' \
  -d 'client_id=admin-cli' \
  "http://${KEYCLOAK_INSTANCE}/auth/realms/master/protocol/openid-connect/token" | jq -r '.access_token'
)

echo "creating ${REALM} realm in Keycloak"
# create realm (also creates a client and user)
curl -s -X POST \
  -H "Authorization: bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "@${KEYCLOAK_REALM_CONFIG}" \
  "http://${KEYCLOAK_INSTANCE}/auth/admin/realms/"

# get the client's id
KEYCLOAK_CLIENT_ID=$(curl -s -X GET \
  -H "Authorization: bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://${KEYCLOAK_INSTANCE}/auth/admin/realms/${REALM}/clients/" | jq -r --arg CLIENT_NAME "${CLIENT_NAME}" '.[] | select(.clientId==$CLIENT_NAME) | .id'
)

# get the client's secret
KEYCLOAK_CLIENT_SECRET=$(curl -s -X GET \
  -H "Authorization: bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "http://${KEYCLOAK_INSTANCE}/auth/admin/realms/${REALM}/clients/${KEYCLOAK_CLIENT_ID}/client-secret" | jq -r '.value'
)

# for use in the auth proxy
export CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET}"
export SESSION_SECRET="${SESSION_SECRET:-$(openssl rand -hex 16)}" # generate a random session secret 32 chars long (if there isn't already one set)

# jq isn't needed anymore so remove from the mounted volume
rm "${COMPOSE_DIR}/jq"

# use host dns resolver so that we can resolve localhost
export NGINX_RESOLVER="$(cat /etc/resolv.conf | grep -i "nameserver" | awk '{print $2}')"

exec /entrypoint.sh
