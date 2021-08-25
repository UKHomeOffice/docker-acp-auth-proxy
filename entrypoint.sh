#!/usr/bin/env bash

# for oidc auth
export CLIENT_AUTH_METHOD="${CLIENT_AUTH_METHOD:-client_secret_post}"
export CLIENT_ID="${CLIENT_ID}"
export CLIENT_SECRET="${CLIENT_SECRET}"
export DISCOVERY_URL="${DISCOVERY_URL}"
export GROUPS_CLAIM="${GROUPS_CLAIM}"
export LOGOUT_PATH="${LOGOUT_PATH:-/oauth/logout}"
export REDIRECT_URL="${REDIRECT_URL:-/oauth/callback}"
export REVOKE_TOKENS_ON_LOGOUT="${REVOKE_TOKENS_ON_LOGOUT:-true}"
export ROLES_CLAIM="${ROLES_CLAIM}"
export SESSION_SECRET="${SESSION_SECRET}"
export SCOPES="openid ${SCOPES}"
export SET_AUTH_HEADER="${SET_AUTH_HEADER:-true}"
export SET_TOKEN_HEADER="${SET_TOKEN_HEADER:-true}"
export SILENT_TOKEN_RENEWAL="${SILENT_TOKEN_RENEWAL:-false}"

# for nginx
export HTTP_LISTEN_PORT="${HTTP_LISTEN_PORT:-8080}"
export HTTPS_LISTEN_PORT="${HTTPS_LISTEN_PORT:-10443}"
export JSON_LOGGING_ENABLED="${JSON_LOGGING_ENABLED:-true}"
export LOG_LEVEL="${LOG_LEVEL:-info}"
export NGINX_RESOLVER="${NGINX_RESOLVER:-8.8.8.8}"
export TLS_CERT="${TLS_CERT:-/certs/tlscert.crt}"
export TLS_PRIVATE_KEY="${TLS_PRIVATE_KEY:-/certs/tlskey.key}"
export UPSTREAM_URL="${UPSTREAM_URL}"

error() {
  case "${1}" in
    1) echo "error: '${2}' is not set" ;;
    2) echo "error: '${2}' not found" ;;
    3) echo "error: Unsupported auth method chosen. Please use either 'client_secret_post' or 'client_secret_basic'" ;;
  esac
  exit ${1}
}

# check for required variables
if [ -z "${DISCOVERY_URL}" ]; then
  error 1 'DISCOVERY_URL'
elif [ -z "${CLIENT_ID}" ]; then
  error 1 'CLIENT_ID'
elif [ -z "${CLIENT_SECRET}" ]; then
  error 1 'CLIENT_SECRET'
elif [ -z "${SESSION_SECRET}" ]; then
  error 1 'SESSION_SECRET'
elif [ -z "${UPSTREAM_URL}" ]; then
  error 1 'UPSTREAM_URL'
fi

# check if cert and key files exist
if [ ! -f "${TLS_CERT}" ]; then
  error 2 "TLS_CERT (path: ${TLS_CERT})"
elif [ ! -f "${TLS_PRIVATE_KEY}" ]; then
  error 2 "TLS_PRIVATE_KEY (path: ${TLS_PRIVATE_KEY})"
fi

# we only support client_secret_post and client_secret_basic at the moment, so check that no other auth method has been set
if [ "${CLIENT_AUTH_METHOD}" != 'client_secret_post' ] && [ "${CLIENT_AUTH_METHOD}" != 'client_secret_basic' ] ; then
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
sed -i "s#\$tls_cert#${TLS_CERT}#g" /usr/local/openresty/nginx/conf/nginx.conf
sed -i "s#\$tls_private_key#${TLS_PRIVATE_KEY}#g" /usr/local/openresty/nginx/conf/nginx.conf

# show configuration in the logs before starting nginx
echo "http listen port: ${HTTP_LISTEN_PORT}"
echo "https listen port: ${HTTPS_LISTEN_PORT}"
echo "upstream url: ${UPSTREAM_URL}"
echo "discovery url: ${DISCOVERY_URL}"
echo "client id: ${CLIENT_ID}"
echo "redirect url: ${REDIRECT_URL}"
echo "tls cert path: ${TLS_CERT}"
echo "tls key path: ${TLS_PRIVATE_KEY}"

# we don't really need to show everything though
if [ "${LOG_LEVEL}" == 'debug' ]; then
  echo "[debug] client auth method: ${CLIENT_AUTH_METHOD}"
  echo "[debug] logout path: ${LOGOUT_PATH}"
  echo "[debug] revoke tokens on logout?: ${REVOKE_TOKENS_ON_LOGOUT}"
  echo "[debug] scopes: ${SCOPES}"
  echo "[debug] set authorzation header?: ${SET_AUTH_HEADER}"
  echo "[debug] set token header?: ${SET_TOKEN_HEADER}"
  echo "[debug] silent token renewal?: ${SILENT_TOKEN_RENEWAL}"
  echo "[debug] nginx resolver: ${NGINX_RESOLVER}"
fi

echo 'starting nginx...'

# start nginx (exec is used so that the container actually responds to Ctrl-C)
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
