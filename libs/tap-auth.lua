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

function private.getUaaUrl()
	return "http://nginx.localnet:8080"
end

function private.retriveTokens()
	--	redirect user to uaa for obtaining authorization code
	local authCode = ngx.var.arg_code
	local result
	if authCode == nil then
		ngx.redirect("/uaa/oauth/authorize?client_id=" .. config.client_id ..
				"&redirect_uri=".. private.getUaaUrl() ..
				"&response_type=code")
	end

	-- getting acces and refresh tokens based on authorization code
	ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")
	local res = ngx.location.capture("/uaa/oauth/token", {method = ngx.HTTP_POST,
		body = "grant_type=authorization_code" ..
				"&code=" .. authCode ..
				"&client_id=" .. config.client_id ..
				"&client_secret=" .. config.client_secret ..
				"&response_type=token" ..
				"&redirect_uri=" .. private.getUaaUrl()})
	assert(res ~= nil, "Cant retrive access token!")
	local resp = cjson.decode(res.body)
	return resp.access_token, resp.refresh_token
end

local function oauth()
	session:verify()
	local access_token = session:get_access_token()
	local refresh_token = session:get_refresh_token()
	if access_token ~= nil then
		local public_key = private.getCACert()
		ngx.log(ngx.INFO, "Access token not found")
		if not private.verify(public_key, access_token) then
			ngx.log(ngx.WARN, "Authorization token not verified")
			ngx.exit(ngx.HTTP_UNAUTHORIZED)
		end
	elseif refresh_token ~= nil then
		--	TODO: implement refreshing access token
	else
		-- create user session and store access and refresh token
		access_token,refresh_token = private.retriveTokens()
		session:set_access_token(access_token)
		session:set_refresh_token(refresh_token)
		local status, err = private.ktinit(access_token)
		session:cookie()
	end
end

--[[
local function auth()
	local auth_header = ngx.var.http_Authorization
	local public_key = private.getCACert()
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
]]

function private.getCACert()
	-- 1. get uaa public key from env
	local pkey = config.public_key
	if pkey == nil and config.public_key_file ~=nil then
		-- 2. or from file, if file location is set
		local f = io.open(config.public_key_file, "rb")
		pkey = f:read("*all")
		f:close()
	end
	if pkey == nil then
		-- 3. or retrive it from uaa server
		pkey = private.retriveCACertFromUaa()
	end
	return pkey
end

function private.retriveCACertFromUaa()
	local res = ngx.location.capture("/uaa/token_key",
	{ method = ngx.HTTP_GET, args = {} })
	local pkey
	if res then
		local resp = cjson.decode(res.body)
		pkey = resp.value
	end
	return pkey
end

function private.verify(public_key, token)
	jwt:set_alg_whitelist({ RS256 = 1 })
	local jwt_obj = jwt:verify(public_key, token, private.claims())
	table.foreach(jwt_obj, function(k, v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
	return jwt_obj.verified
end

function private.claims()
	return {
		exp = validators.is_not_expired(),
		user_id = validators.equals(config.uid)
	}
end

M.auth = auth
M.oauth = oauth
M.setConfig = setConfig
return M