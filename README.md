# docker-acp-auth-proxy

An OpenID Connect (OIDC) authentication proxy based on [Openresty](https://github.com/openresty/docker-openresty/) and using the [lua-resty-openidc](https://github.com/zmartzone/lua-resty-openidc) library.

This has been tested with [Keycloak](https://www.keycloak.org/), however this should be able to be used with any OIDC provider.

## Usage

### Quickstart
#### Docker Compose

A Docker compose configuration is included in this directory to show an example of this image in use. To use it, simply run `docker-compose up`.

> Note: This configuration relies on the containers using `localhost` to communicate, so it uses the host network. Due to https://github.com/docker/for-mac/issues/1031 this means that it not work correctly on a Mac.

The following containers will be started:

- [Keycloak](https://hub.docker.com/r/jboss/keycloak) - The OIDC provider to be used for authentication
- [MariaDB](https://hub.docker.com/_/mariadb) - Used as the backend database for the Keycloak server
- [httpbin](https://hub.docker.com/r/kennethreitz/httpbin) - The upstream application behind the auth proxy
- ACP Auth Proxy - This repo's image

Once the message "starting nginx..." is shown from the auth-proxy container, then all of the containers should be up and ready to use. The Keycloak server will be running on port 8080, so you can go to the admin console by going to `localhost:8080` and login using the admin credentials ("admin" for both the username and the password).

There is a [`bootstrap.sh` script](compose/bootstrap.sh) that runs in the auth proxy image before starting nginx. This script will create a new realm, client and user in Keycloak for use with the auth proxy. See [compose/auth-test-realm.json](compose/auth-test-realm.json) for the specific configuration.

To use the auth proxy, go to `localhost:8081` and login using "testuser" for the username and "securepassword" for the password. You should successfully log in and be sent to httpbin, which is running on port 80. You can also logout again by going adding `/logout` to the url.

#### Kubernetes

Here is an example of how you can use this image in a Kubernetes cluster:

```yaml
...
- name: auth-proxy
  image: quay.io/ukhomeofficedigital/acp-auth-proxy
  ports:
    - containerPort: 8080
      name: http
    - containerPort: 10443
      name: https
  env:
    - name: DISCOVERY_URL
      value: "<OpenID issuer URL>"
    - name: CLIENT_ID
      value: "my-client"
    - name: CLIENT_SECRET
      value: "my-secret"
    - name: SESSION_SECRET
      value: "d4ceec19c5d948539739dbac2efff26f"
    - name: UPSTREAM_URL
      value: "https://google.com"
  securityContext:
    runAsUser: 1000
    runAsNonRoot: true
  livenessProbe:
    httpGet:
      path: /oauth/health
      port: 10443
      scheme: HTTPS
    initialDelaySeconds: 5
    timeoutSeconds: 5
  readinessProbe:
    httpGet:
      path: /oauth/health
      port: 10443
      scheme: HTTPS
    initialDelaySeconds: 5
    timeoutSeconds: 1
  volumeMounts:
...
```

### Environment variables

| Variable | Description | Required | Default |
|:--------:|:-----------:|:--------:|:-------:|
| CLIENT_ID | The Oauth client ID for the application | Y | N/A |
| CLIENT_SECRET | The Oauth client secret for the application | Y | N/A |
| DISCOVERY_URL | The URL to get the OpenID configuration and endpoints. This adds `/.well-known/openid-configuration` to the end of this so this should be the issuer url. Example: `http://localhost/auth/realms/my-realm` | Y | N/A |
| SESSION_SECRET | The secret used to encrypt the session state | Y | N/A |
| UPSTREAM_URL | The upstream endpoint this proxies to after successfully authenticating | Y | N/A |
| CLIENT_AUTH_METHOD | The auth method used for the client (currently this only supports `client_secret_post` and `client_secret_basic`) | N | `client_secret_post` |
| HTTP_LISTEN_PORT | The port this should listen on | N | `8080` |
| HTTPS_LISTEN_PORT | The TLS port this should listen on | N | `10443` |
| GROUPS_CLAIM | The claim that should be used to get the groups from the access token. This does not support nested values (note: this is used to set the `X-Auth-Groups` header) | N | N\A |
| JSON_LOGGING_ENABLED | Should NGINX log using JSON? (note: this only affects the access logs) | N | `true` |
| NGINX_RESOLVER | The DNS server NGINX should use | N | `8.8.8.8` |
| LOG_LEVEL | The NGINX log level | N | `info` |
| LOGOUT_PATH | The path used to logout of the provider | N | `/oauth/logout` |
| REDIRECT_URL | The path the provider will send the user to after authenticating (this can be a path or a full url e.g. `http://localhost/myapp/callback`) | N | `/oauth/callback` |
| REVOKE_TOKENS_ON_LOGOUT | Should the provider revoke the user's access and refresh tokens when they log out? (note: `revocation_endpoint` must be in the list of endpoints returned by the discovery url for this to work. This failing will not stop a logout) | N | `true` |
| ROLES_CLAIM | The claim that should be used to get the roles from the access token. This does not support nested values (note: this is used to set the `X-Auth-Roles` header) | N | `['realm_access']['roles']` |
| SET_AUTH_HEADER | Should the `Authorization: Bearer` header be set? | N | `true` |
| SET_TOKEN_HEADER | Should the `X-Auth-Token` header be set? | N | `true` |
| SCOPES | What additional scopes should be used (`openid` will always be used). Accepted formats: `scope1 scope2`; `scope1, scope2`; `scope1, scope2` | N | N/A |
| SILENT_TOKEN_RENEWAL | Should this silently try to renew the access token when it expires? (if a refresh token is available) | N | `false` |
| TLS_CERT | Path the the TLS cert | N | `/certs/tlscert.crt` (note: this is self-signed) |
| TLS_PRIVATE_KEY | Path the the TLS private key | N | `/certs/tlskey.key` (note: this is self-signed) |

### Configuration

There is a default Nginx configuration provided at that can be found [here](config/nginx.conf) and the image's [entrypoint script](entrypoint.sh) will substitute in values (such as the listen ports) as needed.
We provide some default location blocks [here](config/locations/), that will force authentication on every path except for `/oauth/health`. It will also set various headers that may be useful for the upstream application to consume. The `/oauth/health` location block is intended to be used for checking the health of the container, and requests to it will not be logged. The Lua code that does the authentication can be found [here](config/lua/authenticate.lua).

When using the default Nginx config, you can add extra location blocks by adding them to the `/usr/local/openresty/nginx/conf/locations/` directory (any file with the `.conf` extension will be included). `/usr/local/openresty/nginx/conf/lua/?.lua` is included in Lua's package path, so if you want to add your own functions/modules, you can add them to that directory and use them in your locations

While an Nginx config, location blocks and Lua code for authentication is all provided, these can all be overridden via volume mounts to suit your application's needs. For example, you can override the default location block with your own configuration:
```bash
docker run \
  <other configuration options>
  -v my-custom-default-location.conf:/usr/local/openresty/nginx/conf/locations/default.conf
  quay.io/ukhomeofficedigital/acp-auth-proxy
```
Or if you want to change the Nginx config, you could override it with your own.
> Note: If you override the Nginx config with a volume mount, then you should explicitly set the values in that file, and you may want to override the default command for the image as the `sed` commands will not work as `sed` cannot do an in-place replacement on mounted files (e.g. instead of putting `listen $http_listen_port` like in the default config, set it to an actual value: `listen 8080`).
