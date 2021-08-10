# docker-acp-auth-proxy

# WIP

Uses https://github.com/zmartzone/lua-resty-openidc

Expected to work with Keycloak


## Required env vars (i.e. vars that don't/can't have a default):

### For the lua resty oidc library

KEYCLOAK_DISCOVERY_URL - Expected format `<scheme>://<instance>/auth/realms/<realm>`

KEYCLOAK_CLIENT_ID

KEYCLOAK_CLIENT_SECRET

SESSION_SECRET

### For nginx

UPSTREAM_URL - Expected format `<scheme>://<endpoint>:<port>`

> Note: TLS_CERT and TLS_PRIVATE_KEY are also required because TLS is enabled by default. You can disable this by setting TLS_ENABLED to false.



optional variables:
### For the lua resty oidc library

KEYCLOAK_CLIENT_AUTH_METHOD - Default: `client_secret_post` (must be either `client_secret_post` or `client_secret_basic`)

LOGOUT_PATH - Default: `/oauth/logout`

REDIRECT_URL - Default: `/oauth/callback` (can be a path or a full url e.g. `http://<site>/<whatever>`)

REVOKE_TOKENS_ON_LOGOUT - Default: `true` - note: this will not do anything for Keycloak before v12 as the revocation endpoint was only added to the discovery endpoint in v12: https://issues.redhat.com/browse/KEYCLOAK-14289

SCOPE - Default: `openid`

SET_AUTH_HEADER - Default: `true`

SET_TOKEN_HEADER - Default: `true`

SILENT_TOKEN_RENEWAL - Default: `false` -  try to silently renew the access token when it expires (forces the user to re-auth on failure)

### For nginx

HTTP_LISTEN_PORT - Default: `8080`

HTTPS_LISTEN_PORT - Default: `10443`

TLS_ENABLED - Default: `true`

LOG_LEVEL - Default: `info`

JSON_LOGGING_ENABLED - Default: `true`

NGINX_RESOLVER - Default: `kube-dns.kube-system.svc.cluster.local`
