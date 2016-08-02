local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local cjson = require "cjson"

local uid = os.getenv("USER_ID")
assert(uid ~= nil, "Environment variable USER_ID not set")

local M = {}
local private = {}

local function getCACert(cacert_location) 
  local pkey = os.getenv("JWT_PUBLIC_KEY")
  if pkey == nil then
    local f = io.open(cacert_location, "rb")
    pkey = f:read("*all")
    f:close()
  end
  return pkey
end

local function auth()
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

  if not private.verify(public_key, token) then
      ngx.log(ngx.WARN, "Authorization token not verified")
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end
  
  local status, err = pcall(private.session, token)
  if not status then
      ngx.log(ngx.WARN, "Can't get kerberos ticket: " .. err)
      ngx.exit(ngx.HTTP_UNAUTHORIZED)
  end  
end  

function private.verify(public_key, token)
  jwt:set_alg_whitelist({RS256 = 1})
  local jwt_obj = jwt:verify(public_key, token, private.claims())
  table.foreach(jwt_obj, function(k,v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
  return jwt_obj.verified
end

function private.claims()
  return {
    exp = validators.is_not_expired(),
    user_id = validators.equals(uid)
  }
end 

function private.ktinit(token) 
  local cmd = string.format("ktinit -t %s -c %s", token, "/tmp/krb5cc")
  local exit_code =  os.execute(cmd)
  if exit_code ~= 0 then 
     error(string.format("Execution failed: %s, [exit code: %02d]", cmd, exit_code))
  else  
     return exit_code
  end
end

function private.session(token)
  local session_id  = ngx.var.cookie_session;
  if session_id == nil then
    local expires = 60 * 5 -- five minutes
    local status, err = private.ktinit(token)
    --TODO generate session id
    session_id = uid
    ngx.header["Set-Cookie"] = 
       string.format("session=%s; Path=/; Expires=%s", 
                      session_id, 
                      ngx.cookie_time(ngx.time() + expires))
  end
  return session_id
end 

M.getCACert = getCACert
M.auth = auth
return M
