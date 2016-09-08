local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local cjson = require "cjson"

local M = {}
local private = {}
local config

local function setConfig(conf)
	assert(conf.uid ~= nil, "Environment variable USER_ID not set")
	config = conf
end

--[[
function private.getRedirectUri()
	return "http://nginx.localnet:8080"
end
]]

function private.jsonRespDecode(response)
	assert(response ~= nil, "Cant retrive token!")
	if response.status == ngx.HTTP_OK then
		local res = cjson.decode(response.body)
		return res
	elseif response.status == ngx.HTTP_REQUEST_TIMEOUT then
		ngx.log(ngx.ERR, "UAA server connection timeout!")
		ngx.exit(ngx.HTTP_UNAUTHORIZED)
	elseif response.status == ngx.HTTP_BAD_REQUEST then
		if response.body ~= nil then
			local res = cjson.decode(response.body)
			ngx.log(ngx.ERR, res.error .. " - " .. res.error_description)
			ngx.exit(ngx.HTTP_UNAUTHORIZED)
		end
	elseif response.status == ngx.HTTP_UNAUTHORIZED then
		ngx.log(ngx.ERR, "Bad credentials for oauth client (CLIENT_ID or/and CLIENT_SECRET)!")
		ngx.exit(ngx.HTTP_UNAUTHORIZED)
	else
		ngx.log(ngx.ERR, "Unrecoginzed response from UAA server! [" .. response.status .. "]")
		ngx.exit(ngx.HTTP_UNAUTHORIZED)
	end
end

function private.retriveTokens()
	--	redirect user to uaa for obtaining authorization code
	local authCode = ngx.var.arg_code
	local result
	if authCode == nil then
		ngx.redirect("http://" .. config.uaa .. "/oauth/authorize?client_id=" .. config.client_id ..
				--[["&redirect_uri=".. private.getRedirectUri() ..]]
				"&response_type=code")
	end

	-- getting acces and refresh tokens based on authorization code
	ngx.req.set_header("content-type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = ngx.location.capture("/oauth/token", {method = ngx.HTTP_POST,
		body = "grant_type=authorization_code" ..
				"&code=" .. authCode ..
				"&client_id=" .. config.client_id ..
				"&client_secret=" .. config.client_secret ..
				"&response_type=token" --[[..
				"&redirect_uri=" .. private.getRedirectUri()]]})
	local resp = private.jsonRespDecode(res)
	return resp.access_token, resp.refresh_token
end

function private.refreshAccessToken(refreshToken)
	ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = ngx.location.capture("/oauth/token", {method = ngx.HTTP_POST,
		body = "grant_type=refresh_token" ..
				"&refresh_token=" .. refreshToken ..
				"&client_id=" .. config.client_id ..
				"&client_secret=" .. config.client_secret})
	local resp = private.jsonRespDecode(res)
	return resp.access_token
end

local function oauth(session)
	session:isValidSession()
	       :aquireOauthTokens(private.retriveTokens, private.refreshAccessToken)
	       :checkAccess(private.checkIfAuthorizedMethod())
	       :refreshTokenIfExpired(private.checkExpirationMethod())
	       :grantAccess(private.ktinit)
end

function private.getCACert()
	local pkey = ngx.shared.public_key:get("pk")
	if pkey == nil then
		-- 1. get uaa public key from env
		pkey = config.public_key
		ngx.shared.public_key:set("pk", pkey)
		if pkey == nil and config.public_key_file ~= nil then
			-- 2. or from file, if file location is set
			local f = io.open(config.public_key_file, "rb")
			pkey = f:read("*all")
			f:close()
			ngx.shared.public_key:set("pk", pkey)
		end
		if pkey == nil then
			-- 3. or retrive it from uaa server
			pkey = private.retriveCACertFromUaa()
			ngx.shared.public_key:set("pk", pkey)
		end
	end
	return pkey
end

function private.retriveCACertFromUaa()
	local resp = ngx.location.capture("/token_key",
	{ method = ngx.HTTP_GET, args = {} })
	local res = private.jsonRespDecode(resp)
	return res.value
end

function private.verify(public_key, token, claims)
	jwt:set_alg_whitelist({ RS256 = 1 })
	local jwt_obj = jwt:verify(public_key, token, claims)
	table.foreach(jwt_obj, function(k, v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
	return jwt_obj.verified
end

function private.identityClaims()
	return {
		user_id = validators.equals(config.uid)
	}
end

function private.expirationClaims()
	return {
		exp = validators.is_not_expired()
	}
end

function private.checkIfAuthorizedMethod()
	local pk = private.getCACert()
	return function(token)
		ngx.log(ngx.INFO, "Check access method invocation!")
		return private.verify(pk, token, private.identityClaims())
	end
end

function private.checkExpirationMethod()
	local pk = private.getCACert()
	return function(token)
		ngx.log(ngx.INFO, "Check token method invocation!")
		return private.verify(pk, token, private.expirationClaims())
	end
end

function private.ktinit(token)
	local cmd = string.format("ktinit -t %s -c %s", token, "/tmp/krb5cc")
	ngx.log(ngx.INFO, "Ktinit invocation!")
	local exit_code =  os.execute(cmd)
	if exit_code ~= 0 then
		error(string.format("Execution failed: %s, [exit code: %02d]", cmd, exit_code))
	else
		return exit_code
	end
end

M.oauth = oauth
M.setConfig = setConfig
return M