local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local cjson = require "cjson"

local uid = os.getenv("USER_ID")
assert(uid ~= nil, "Environment variable USER_ID not set")

local M = {}

function M.getCACert(cacert_location) 
  local pkey = os.getenv("JWT_PUBLIC_KEY")
  if pkey == nil then
    local f = io.open(cacert_location, "rb")
    pkey = f:read("*all")
    f:close()
  end
  return pkey
end

function M.auth()
  local auth_header = ngx.var.http_Authorization
  if auth_header == nil then
    ngx.log(ngx.INFO, "No Authorization header")
    ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end 

  local _, _, token = string.find(auth_header, "Bearer%s+(.+)")
  if token == nil then
      ngx.log(ngx.WARN, "Invalid authorization header - missing token")
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  if not M.verify(public_key, token) then
      ngx.log(ngx.WARN, "Authorization token not verified")
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end

  local exit_code = M.ktinit(token)
  if not exit_code == 0 then
      ngx.log(ngx.WARN, "Can't get kerberos ticket")
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end  
end  

function M.verify(public_key, token)
  jwt:set_alg_whitelist({RS256 = 1})
  local jwt_obj = jwt:verify(public_key, token, M.claims())
  table.foreach(jwt_obj, function(k,v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
  return jwt_obj.verified
end

function M.claims()
  return {
    exp = validators.is_not_expired(),
    user_id = validators.equals(uid)
  }
end 

function M.ktinit(token) 
  local cmd = string.format("ktinit -t %s -c %s", token, "/tmp/krb5cc")
  ngx.log(ngx.INFO, cmd)
  return os.execute(cmd)
end

return M
