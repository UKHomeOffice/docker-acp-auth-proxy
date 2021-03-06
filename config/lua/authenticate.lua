-- a lua module is used to prevent a warning about using global lua functions
-- without doing this, the functions will show a warning when called saying that you should make them local instead
-- it doesn't affect you actually calling the function, but the warning is logged which can be annoying

-- define a module to hold all of the functions
local auth_module = { }

function auth_module.authenticate_user()
  local opts = {
    discovery = os.getenv("DISCOVERY_URL") .. "/.well-known/openid-configuration",
    client_id = os.getenv("CLIENT_ID"),
    client_secret = os.getenv("CLIENT_SECRET"),
    redirect_uri = os.getenv("REDIRECT_URL"),
    token_endpoint_auth_method = os.getenv("CLIENT_AUTH_METHOD"),
    logout_path = os.getenv("LOGOUT_PATH"),
    revoke_tokens_on_logout = os.getenv("REVOKE_TOKENS_ON_LOGOUT"),
    post_logout_redirect_uri = ngx.var.scheme .. "://" .. ngx.var.http_host, -- the user will be sent back to the application's "homepage" after logging out
    renew_access_token_on_expiry = os.getenv("SILENT_TOKEN_RENEWAL"),
    scope = os.getenv("SCOPES"):gsub(", ", " "):gsub(",", " ") -- replace commas with spaces
  }

  -- authenticate user using OIDC auth flow
  local res, err = require("resty.openidc").authenticate(opts)

  if err then
    ngx.log(ngx.ERR, "There was an error while a user attempted to log in: " .. tostring(err))

    ngx.header.content_type = 'text/html';
    ngx.status = 500
    ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
  end

  ngx.log(ngx.DEBUG, res.user.name .. " has successfully authenticated")
  return res
end

-- used to validate the token from the authorization bearer header (this assumes that the header has already been set)
function auth_module.validate_token()
  local opts = {
    discovery = os.getenv("DISCOVERY_URL") .. "/.well-known/openid-configuration",
    token_signing_alg_values_expected = "RS256",
    accept_unsupported_alg = false
  }

  -- validate bearer token
  local res, err = require("resty.openidc").bearer_jwt_verify(opts)

  -- will error if the token is not valid or if the auth header has not been set
  if err then
    ngx.log(ngx.ERR, tostring(err))
    ngx.status = 403
    ngx.header.content_type = 'text/html';
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end

  -- check if the client id is from an allowed client
  if type(res.aud) == "string" then
    if res.aud ~= os.getenv("CLIENT_ID") then
      ngx.log(ngx.ERR, "aud does not match correct client")
      auth_module.reject_as_forbidden()
    end
  elseif type(res.aud) == "table" then
    if not auth_module.contains(res.aud, os.getenv("CLIENT_ID")) then
      ngx.log(ngx.ERR, "aud does not match correct client")
      auth_module.reject_as_forbidden()
    end
  else
    -- this shouldn't really happen
    ngx.log(ngx.ERR, "aud is not a string or table; aud = " .. tostring(res.aud) .. "; aud type = " .. type(res.aud))
    auth_module.reject_as_forbidden()
  end
end

-- check if a table contains a given value
-- adapted from https://github.com/zmartzone/lua-resty-openidc/issues/322#issuecomment-606023074
function auth_module.contains(list, value)
  for _, element in pairs(list) do
      if element == value then return true end
  end
  return false
end

function auth_module.reject_as_forbidden()
  ngx.header.content_type = 'text/html';
  ngx.status = 403
  ngx.exit(ngx.HTTP_FORBIDDEN)
end

return auth_module
