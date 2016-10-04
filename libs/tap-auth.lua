TapAuth = {}
TapAuth.__index = TapAuth

setmetatable(TapAuth, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function TapAuth.new(conf, jwt, validators, cjson)
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

function TapAuth:setNgxContext(context)
	self.ngx = context
end

function TapAuth:jsonRespDecode(response)
	assert(response ~= nil, "Can't retrive token!")
	if response.status == self.ngx.HTTP_OK then
		local res = self.cjson.decode(response.body)
		return res
	elseif response.status == self.ngx.HTTP_REQUEST_TIMEOUT then
		self.terminateProcessing("UAA server connection timeout!")
	elseif response.status == self.ngx.HTTP_BAD_REQUEST then
		if response.body ~= nil then
			local res = self.cjson.decode(response.body)
			self.terminateProcessing(res.error .. " - " .. res.error_description)
		end
	elseif response.status == self.ngx.HTTP_UNAUTHORIZED then
		self.terminateProcessing("Bad credentials for oauth client (CLIENT_ID or/and CLIENT_SECRET)!")
	else
		self.terminateProcessing("Unrecoginzed response from UAA server! [" .. response.status .. "]")
	end
end

function TapAuth:retriveTokens()
	--	redirect user to uaa for obtaining authorization code
	local authCode = self.ngx.var.arg_code
	local result
	if authCode == nil then
		if self.config.uaaAuthorizationUri ~= nil then
			self.ngx.redirect(self.config.uaaAuthorizationUri .. "?client_id=" .. self.config.client_id ..
					"&response_type=code")
			return
		else
			self.ngx.redirect(self.config.uaa .. "/oauth/authorize?client_id=" .. self.config.client_id ..
					"&response_type=code")
			return
		end
	end

	-- getting acces and refresh tokens based on authorization code
	self.ngx.req.set_header("content-type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = self.ngx.location.capture("/oauth/token", {method = self.ngx.HTTP_POST,
		body = "grant_type=authorization_code" ..
				"&code=" .. authCode ..
				"&client_id=" .. self.config.client_id ..
				"&client_secret=" .. self.config.client_secret ..
				"&response_type=token"
			})
	local resp = self:jsonRespDecode(res)
	return resp.access_token, resp.refresh_token
end

function TapAuth:retriveTokensMethod()
	return function()
		return TapAuth.retriveTokens(self)
	end
end

function TapAuth:refreshAccessToken(refreshToken)
	self.ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded;charset=utf-8")
	local res = self.ngx.location.capture("/oauth/token", {method = self.ngx.HTTP_POST,
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
	local pkey = self.ngx.shared.public_key:get("pk")
	if pkey == nil then
		-- 1. get uaa public key from env
		pkey = self.config.public_key
		self.ngx.shared.public_key:set("pk", pkey)
		if pkey == nil and self.config.public_key_file ~= nil then
			-- 2. or from file, if file location is set
			local f = io.open(self.config.public_key_file, "rb")
			pkey = f:read("*all")
			f:close()
			self.ngx.shared.public_key:set("pk", pkey)
		end
		if pkey == nil then
			-- 3. or retrive it from uaa server
			pkey = self:retriveCACertFromUaa()
			self.ngx.shared.public_key:set("pk", pkey)
		end
	end
	return pkey
end

function TapAuth:retriveCACertFromUaa()
	local resp = self.ngx.location.capture("/token_key",
	{ method = self.ngx.HTTP_GET, args = {} })
	local res = self:jsonRespDecode(resp)
	return res.value
end

function TapAuth:verify(public_key, token, claims)
	jwt:set_alg_whitelist({ RS256 = 1 })
	local jwt_obj = self.jwt:verify(public_key, token, claims)
	table.foreach(jwt_obj,
		            function(k, v) self.ngx.log(self.ngx.INFO, tostring(k) .. "=>" .. tostring(v)) end)
	return jwt_obj.verified
end

function TapAuth:identityClaims()
	return {
		user_id = self.validators.equals(self.config.uid)
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
		self.ngx.log(self.ngx.INFO, "Check access method invocation! " .. token)
		return self:verify(pk, token, self:identityClaims())
	end
end

function TapAuth:checkExpirationMethod()
	local pk = self:getCACert()
	return function(token)
		self.ngx.log(self.ngx.INFO, "Check token method invocation!")
		return self:verify(pk, token, self:expirationClaims())
	end
end

function TapAuth.ktinit(token)
	local cmd = string.format("ktinit -t %s -c %s", token, "/tmp/krb5cc")
	local exit_code =  os.execute(cmd)
	if exit_code ~= 0 then
		error(string.format("Execution failed: %s, [exit code: %02d]", cmd, exit_code))
	else
		return exit_code
	end
end

function TapAuth:terminateProcessing(message)
	self.ngx.log(self.ngx.ERR, message)
	self.ngx.exit(self.ngx.HTTP_UNAUTHORIZED)
end