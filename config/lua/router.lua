local config = require("/etc/nginx/lua/config")
local routerlib = require("/etc/nginx/lua/routerlib")

local deployment_group = nil
local deployment_version = nil
local routing_query_param_value = nil

-- Get the value for a request header
function get_request_header(name)
  return ngx.var['http_' .. string.lower(string.gsub(name, "-", "_"))]
end

-- Convert the header value into a numeric value and obtain the rest of total_partitions_weight
-- to infer the deployment group.
function get_deployment_group_from_header(header_value)
  local value = 0
  for i = 1, string.len(header_value) do
    value = value + string.byte(header_value, i)
  end
  value = 1 / (1 + value)
  return routerlib.get_deployment_group_from_value(value)
end

-- Remove a query parameter from the request query parameters
function remove_query_param(query_param)
  local args = ngx.req.get_uri_args()
  args[query_param] = nil
  local query_params = ""
  for key, val in pairs(args) do
    if query_params ~= "" then
      query_params = query_params .. "&"
    end
    query_params = query_params .. key .. "=" .. val
  end
  return query_params
end

-- Create cookies to store deployment_group and deployment version
function create_cookies(deployment_version, deployment_group, domain)
  -- If domain is empty (localhost) or the domain is already prefixed with a dot, do not prepend a dot
  if domain ~= "" and domain:sub(1, 1) ~= "." then
    domain = "." .. domain
  end
  local common_data_cookie = ";path=/;HttpOnly;domain=" .. domain
                          .. ";Expires=" .. ngx.cookie_time(ngx.time() + 3600 * 24 * 365)
  local deployment_group_cookie =  "deployment_group=" .. deployment_group
                                    .. common_data_cookie
  local deployment_version_cookie = "deployment_version=" .. deployment_version
                                    .. common_data_cookie

  ngx.header["Set-Cookie"] = {deployment_group_cookie, deployment_version_cookie}
end

-- Check if deployment_group is forced by query param (routing_query_param)
if config["routing_query_param"] ~= "" then
  local args = ngx.req.get_uri_args()
  deployment_group = args[config["routing_query_param"]]
  routing_query_param_value = deployment_group
  -- ngx.log(ngx.DEBUG, "Deployment group by query param '", config["routing_query_param"], "': ", deployment_group)
end

-- Check if deployment_group is forced by header (routing_header)
if not deployment_group and config["routing_header"] ~= "" then
  deployment_group = get_request_header(config["routing_header"])
  -- ngx.log(ngx.DEBUG, "Deployment group by routing header '", config["routing_header"], "': ", deployment_group)
end

-- If cookies are set, then get the deployment group from the cookie (if available)
-- if deployment_group is available in the cookie and can be used for product version
-- it will be used
local invalid_cookie = true
if not deployment_group and config["cookies"] then
  local deployment_version = ngx.var.cookie_deployment_version
  local cookie_deployment_group = ngx.var.cookie_deployment_group
  -- ngx.log(ngx.DEBUG, "From cookie, deployment version: ", deployment_version)
  if deployment_version then
    -- if cookie has deployment group valid for deployment_version, follow it
    cookie_deployment_version = routerlib.get_version_from_deployment_group(cookie_deployment_group)
    if cookie_deployment_version and cookie_deployment_version == deployment_version then
        -- ngx.log(ngx.DEBUG, "From cookie, deployment group: ", cookie_deployment_group)
        deployment_group = cookie_deployment_group
        invalid_cookie = false
    else
        deployment_group = routerlib.get_deployment_group_from_version(deployment_version)
        -- ngx.log(ngx.DEBUG, "From version, deployment group: ", deployment_group) 
    end
  end
end

-- Get the deployment group from "Authorization" header if policy is "header_authorization"
-- but deployment_group is not available yet
if not deployment_group and config["policy"] == "header_authorization" then
  local authorization = get_request_header("authorization")
  if authorization then
    deployment_group = get_deployment_group_from_header(authorization)
    -- ngx.log(ngx.DEBUG, "Deployment group by authorization header: ", deployment_group)
  end
end

-- Check if deployment group is valid. If invalid, set to nil to force a random deployment group
if deployment_group and not routerlib.is_valid_deployment_group(deployment_group) then
  deployment_group = nil
end

-- If not deployment group yet, obtain with random policy
if not deployment_group then
  local value = math.random()
  deployment_group = routerlib.get_deployment_group_from_value(value)
  -- ngx.log(ngx.DEBUG, "Deployment group by random policy: ", deployment_group)
end

deployment_version = routerlib.get_version_from_deployment_group(deployment_group)

-- Create the cookie when cookies is true and the cookie was not set yet or
-- its value was overriden.
if config["cookies"] and invalid_cookie then
  -- ngx.log(ngx.DEBUG, "invalid cookie")
  if deployment_version then
    create_cookies(deployment_version, deployment_group, config["domain"])
    -- ngx.log(ngx.DEBUG, "Created cookies with deployment version: ", deployment_version, " and deployment group: ", deployment_group)
  else
    ngx.log(ngx.ERR, "Cookie not created. No version found for deployment group: ", deployment_group)
  end
  -- If routing_query_param_value set the deployment group, then remove this
  -- query parameter and perform a redirection
  if routing_query_param_value == deployment_group then
    local query_params = remove_query_param(config["routing_query_param"])
    local redirect_uri = query_params == "" and ngx.var.uri or ngx.var.uri .. "?" .. query_params
    -- ngx.log(ngx.DEBUG, "Redirect with URL: ", redirect_uri)
    ngx.redirect(redirect_uri)
  end
end

-- ngx.log(ngx.DEBUG, "Forward to deployment group: ", deployment_group, " with version: ", deployment_version)
ngx.var.user_upstream = deployment_group
