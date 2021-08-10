#!/usr/bin/env bash

# for oidc auth
export KEYCLOAK_CLIENT_AUTH_METHOD="${KEYCLOAK_CLIENT_AUTH_METHOD:-client_secret_post}"
export KEYCLOAK_CLIENT_ID="${KEYCLOAK_CLIENT_ID}"
export KEYCLOAK_CLIENT_SECRET="${KEYCLOAK_CLIENT_SECRET}"
export KEYCLOAK_DISCOVERY_URL="${KEYCLOAK_DISCOVERY_URL}"
export LOGOUT_PATH="${LOGOUT_PATH:-/oauth/logout}"
export REDIRECT_URL="${REDIRECT_URL:-/oauth/callback}" # can be a path or a full url e.g. http://<site>/<whatever>
export REVOKE_TOKENS_ON_LOGOUT="${REVOKE_TOKENS_ON_LOGOUT:-true}"
export SESSION_SECRET="${SESSION_SECRET}"
export SCOPE="${SCOPE:-openid}"
export SET_AUTH_HEADER="${SET_AUTH_HEADER:-true}"
export SET_TOKEN_HEADER="${SET_TOKEN_HEADER:-true}"
export SILENT_TOKEN_RENEWAL="${SILENT_TOKEN_RENEWAL:-false}"

# for nginx
export HTTP_LISTEN_PORT="${HTTP_LISTEN_PORT:-8080}"
export HTTPS_LISTEN_PORT="${HTTPS_LISTEN_PORT:-10443}"
export UPSTREAM_URL="${UPSTREAM_URL}"

export TLS_ENABLED="${TLS_ENABLED:-true}"
export TLS_CERT="${TLS_CERT}"
export TLS_PRIVATE_KEY="${TLS_PRIVATE_KEY}"

export LOG_LEVEL="${LOG_LEVEL:-info}"
export JSON_LOGGING_ENABLED="${JSON_LOGGING_ENABLED:-true}"

export NGINX_RESOLVER="${NGINX_RESOLVER:-kube-dns.kube-system.svc.cluster.local}"

error() {
  case "${1}" in
    1) echo "error: '${2}' is not set" ;;
    2) echo "error: TLS is enabled but '${2}' not found" ;;
    3) echo "error: Unsupported auth method chosen. Please use either 'client_secret_post' or 'client_secret_basic'" ;;
  esac
  exit ${1}
}

# check for required variables
if [ -z "${KEYCLOAK_CLIENT_ID}" ]; then
  error 1 'KEYCLOAK_CLIENT_ID'
elif [ -z "${KEYCLOAK_CLIENT_SECRET}" ]; then
  error 1 'KEYCLOAK_CLIENT_SECRET'
elif [ -z "${KEYCLOAK_DISCOVERY_URL}" ]; then
  error 1 'KEYCLOAK_DISCOVERY_URL'
elif [ -z "${SESSION_SECRET}" ]; then
  error 1 'SESSION_SECRET'
elif [ -z "${UPSTREAM_URL}" ]; then
  error 1 'UPSTREAM_URL'
fi

# check if TLS should be enabled and if the cert and key have been provided
if [ "${TLS_ENABLED}" == 'true' ]; then
  if [ -z "${TLS_CERT}" ] || [ ! -f "${TLS_CERT}" ]; then
    error 2 'TLS_CERT'
  elif [ -z "${TLS_PRIVATE_KEY}" ] || [ ! -f "${TLS_PRIVATE_KEY}" ]; then
    error 2 'TLS_PRIVATE_KEY'
  fi
fi

# we only support client_secret_post and client_secret_basic atm, so check that no other auth method has been set
if [ "${KEYCLOAK_CLIENT_AUTH_METHOD}" != 'client_secret_post' ] && [ "${KEYCLOAK_CLIENT_AUTH_METHOD}" != 'client_secret_basic' ] ; then
  error 3
fi

if [ "${JSON_LOGGING_ENABLED}" == 'true' ]; then
  LOG_TYPE="combined_json"
else
  LOG_TYPE="combined"
fi

# note: sed will fail if the nginx.conf file is being mounted, but the error will not stop the script from continuing
# nginx doesn't support variables being used for these, so we need to replace them with actual values
sed -i "s/\$http_listen_port/${HTTP_LISTEN_PORT}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i "s/\$https_listen_port/${HTTPS_LISTEN_PORT}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i "s/\$log_level/${LOG_LEVEL}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i "s/\$log_type/${LOG_TYPE}/g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i "s/\$resolver/${NGINX_RESOLVER}/g" /usr/local/openresty/nginx/conf/nginx.conf

# show configuration in logs
echo "http listen port: ${HTTP_LISTEN_PORT}"
echo "upstream url: ${UPSTREAM_URL}"
echo "discovery url: ${KEYCLOAK_DISCOVERY_URL}"
echo "redirect url: ${REDIRECT_URL}"
if [ "${TLS_ENABLED}" == 'true' ]; then
  echo "tls is enabled. https listen port: ${HTTPS_LISTEN_PORT}"
  echo "cert path: ${TLS_CERT}"
  echo "key path: ${TLS_PRIVATE_KEY}"
else
  echo "tls is not enabled."
fi

if [ "${LOG_LEVEL}" == 'debug' ]; then
  echo "[debug] client id: ${KEYCLOAK_CLIENT_ID}"
  echo "[debug] client auth method: ${KEYCLOAK_CLIENT_AUTH_METHOD}"
  echo "[debug] logout path: ${LOGOUT_PATH}"
  echo "[debug] revoke tokens on logout?: ${REVOKE_TOKENS_ON_LOGOUT}"
  echo "[debug] scope: ${SCOPE}"
  echo "[debug] set authorzation header?: ${SET_AUTH_HEADER}"
  echo "[debug] set token header?: ${SET_TOKEN_HEADER}"
  echo "[debug] silent token renewal?: ${SILENT_TOKEN_RENEWAL}"
  echo "[debug] nginx resolver: ${NGINX_RESOLVER}"
fi

echo 'starting nginx...'

# start nginx (exec is used so that this container actually responds to Ctrl-C)
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
