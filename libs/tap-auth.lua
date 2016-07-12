local jwt = require "resty.jwt"
local cjson = require "cjson"
local public_key = os.getenv("JWT_PUBLIC_KEY")

assert(public_key ~= nil, "Environment variable JWT_PUBLIC_KEY not set")

local M = {}

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

  M.verify(public_key, token)
end  

function M.verify(public_key, token)
  ngx.log(ngx.INFO, public_key)
  ngx.log(ngx.INFO, token)
  jwt:set_alg_whitelist({RS256 = 1})
  local jwt_obj = jwt:verify(public_key, token)
  table.foreach(jwt_obj, function(k,v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
end

return M
