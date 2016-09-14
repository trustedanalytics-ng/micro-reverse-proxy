TapAuth = {}
TapAuth.__index = TapAuth

setmetatable(TapAuth, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function TapAuth.new(conf, jwt, validators, cjson)
	ngx.log(ngx.INFO, "TAP Auth instance created")
	assert(conf ~= nil, "Coniguration refers to nil!")
	assert(jwt ~= nil, "JWT parser refers to nil!")
	assert(validators  ~= nil, "Validators refers to nil!")
	assert(cjson  ~= nil, "JSON parser refers to nil!")
	local self = setmetatable({}, TapAuth)

	self.config = conf
	self.jwt = jwt
	self.validators = validators
	self.cjson = cjson

	return self
end

function TapAuth:jsonRespDecode(response)
	assert(response ~= nil, "Cant retrive token!")
	if response.status == ngx.HTTP_OK then
		local res = cjson.decode(response.body)
		return res
	elseif response.status == ngx.HTTP_REQUEST_TIMEOUT then
		self.terminateProcessing("UAA server connection timeout!")
	elseif response.status == ngx.HTTP_BAD_REQUEST then
		if response.body ~= nil then
			local res = cjson.decode(response.body)
			self.terminateProcessing(res.error .. " - " .. res.error_description)
		end
	elseif response.status == ngx.HTTP_UNAUTHORIZED then
		self.terminateProcessing("Bad credentials for oauth client (CLIENT_ID or/and CLIENT_SECRET)!")
	else
		self.terminateProcessing("Unrecoginzed response from UAA server! [" .. response.status .. "]")
	end
end

function TapAuth:retriveTokens()
	--	redirect user to uaa for obtaining authorization code
	local authCode = ngx.var.arg_code
	local result
	if authCode == nil then
		if self.config.uaaAuthorizationUri ~= nil then
			ngx.redirect(self.config.uaaAuthorizationUri .. "?client_id=" .. self.config.client_id ..
					"&response_type=code")
		else
			ngx.redirect(self.config.uaa .. "/oauth/authorize?client_id=" .. self.config.client_id ..
					"&response_type=code")
		end
	end

	-- getting acces and refresh tokens based on authorization code
	ngx.req.set_header("content-type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = ngx.location.capture("/oauth/token", {method = ngx.HTTP_POST,
		body = "grant_type=authorization_code" ..
				"&code=" .. authCode ..
				"&client_id=" .. self.config.client_id ..
				"&client_secret=" .. self.config.client_secret ..
				"&response_type=token"
			})
	local resp = self:jsonRespDecode(res)
	ngx.log(ngx.INFO, "access token: " .. resp.access_token)
	ngx.log(ngx.INFO, "refresh token: " .. resp.refresh_token)
	return resp.access_token, resp.refresh_token
end

function TapAuth:retriveTokensMethod()
	return function()
		return TapAuth.retriveTokens(self)
	end
end

function TapAuth:refreshAccessToken(refreshToken)
	ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = ngx.location.capture("/oauth/token", {method = ngx.HTTP_POST,
		body = "grant_type=refresh_token" ..
				"&refresh_token=" .. refreshToken ..
				"&client_id=" .. self.config.client_id ..
				"&client_secret=" .. self.config.client_secret})
	local resp = self:jsonRespDecode(res)
	return resp.access_token
end

function TapAuth:refreshAccessTokenMethod()
	return function(refreshToken)
		return TapAuth.refreshAccessToken(self, refreshToken)
	end
end

function TapAuth:getCACert()
	local pkey = ngx.shared.public_key:get("pk")
	if pkey == nil then
		-- 1. get uaa public key from env
		pkey = self.config.public_key
		ngx.shared.public_key:set("pk", pkey)
		if pkey == nil and self.config.public_key_file ~= nil then
			-- 2. or from file, if file location is set
			local f = io.open(self.config.public_key_file, "rb")
			pkey = f:read("*all")
			f:close()
			ngx.shared.public_key:set("pk", pkey)
		end
		if pkey == nil then
			-- 3. or retrive it from uaa server
			pkey = self:retriveCACertFromUaa()
			ngx.shared.public_key:set("pk", pkey)
		end
	end
	return pkey
end

function TapAuth:retriveCACertFromUaa()
	local resp = ngx.location.capture("/token_key",
	{ method = ngx.HTTP_GET, args = {} })
	local res = self:jsonRespDecode(resp)
	return res.value
end

function TapAuth:verify(public_key, token, claims)
	jwt:set_alg_whitelist({ RS256 = 1 })
	local jwt_obj = jwt:verify(public_key, token, claims)
	table.foreach(jwt_obj, function(k, v) ngx.log(ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
	return jwt_obj.verified
end

function TapAuth:identityClaims()
	return {
		user_id = self.validators.equals(config.uid)
	}
end

function TapAuth:expirationClaims()
	return {
		exp = self.validators.is_not_expired()
	}
end

function TapAuth:checkIfAuthorizedMethod()
	local pk = self:getCACert()
	return function(token)
		ngx.log(ngx.INFO, "Check access method invocation! " .. token)
		return self:verify(pk, token, self:identityClaims())
	end
end

function TapAuth:checkExpirationMethod()
	local pk = self:getCACert()
	return function(token)
		ngx.log(ngx.INFO, "Check token method invocation!")
		return self:verify(pk, token, self:expirationClaims())
	end
end

function TapAuth.ktinit(token)
	local cmd = string.format("ktinit -t %s -c %s", token, "/tmp/krb5cc")
	ngx.log(ngx.INFO, "Ktinit invocation!")
	local exit_code =  os.execute(cmd)
	if exit_code ~= 0 then
		error(string.format("Execution failed: %s, [exit code: %02d]", cmd, exit_code))
	else
		return exit_code
	end
end

function TapAuth:terminateProcessing(message)
	ngx.log(ngx.ERR, message)
	ngx.exit(ngx.HTTP_UNAUTHORIZED)
end