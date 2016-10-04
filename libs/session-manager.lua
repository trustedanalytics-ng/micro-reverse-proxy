SessionMgr = {}
SessionMgr.__index = SessionMgr

setmetatable(SessionMgr, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function SessionMgr.new(context, config)
	assert(context.shared.session_store ~= nil, "Session store not set!")
	local self = setmetatable({}, SessionMgr)

	-- generating session id
	local md5Inst = md5:new()
	local str = require "resty.string"
	if config.uid ~= nil then
		md5Inst:update(config.uid)
	end
	md5Inst:update(config.session_seed)
	local digest = md5Inst:final()
	self.session_id = str.to_hex(digest)
	self.store = context.shared.session_store
	self.ngx = context
	self.access_token = nil
	self.refresh_token = nil
	return self
end

function SessionMgr:aquireOauthTokens(aquisitionMethod, refreshMethod)
	local session_id = self.ngx.var.cookie_session;
	self.tokensAquisitionMethod = aquisitionMethod
	self.accessTokenRefreshMethod = refreshMethod
	self.access_token = self:get_access_token();
	self.refresh_token = self:get_refresh_token();
	if self.access_token == nil or
			self.refresh_token == nil or
			session_id == nil then
		  self.access_token,self.refresh_token = aquisitionMethod()
	end
	return self
end

function SessionMgr:checkAccess(hasAccess)
	if not hasAccess(self.access_token) then
		self.terminate("Not authorized access attempt!")
	end
	return self
end

function SessionMgr:refreshTokenIfExpired(checkIfNotExpired)
	if not checkIfNotExpired(self.access_token) then
		self.ngx.log(self.ngx.INFO, "Access token expired! " .. self.access_token)
		if not checkIfNotExpired(self.refresh_token) then
			self.ngx.log(self.ngx.INFO, "Refresh token expired. " .. self.refresh_token)
			self.access_token,self.refresh_token = self.tokensAquisitionMethod()
		else
			self.ngx.log(self.ngx.INFO, "Refreshing access token using refresh token! " .. self.refresh_token)
			self.access_token = self.accessTokenRefreshMethod(self.refresh_token)
		end
	end
	return self
end

function SessionMgr:set_access_token(token)
	local succ, err, forcible = self.store:set("access_token", token)
end

function SessionMgr:get_access_token()
	local value, flags = self.store:get("access_token")
	return value
end

function SessionMgr:set_refresh_token(token)
	local succ, err, forcible = self.store:set("refresh_token", token)
end

function SessionMgr:get_refresh_token()
	local value, flags = self.store:get("refresh_token")
	return value
end

function SessionMgr:get_session_id()
	return self.session_id
end

function SessionMgr:grantAccess(grantingAccessMethod)
	local session_id = self.ngx.var.cookie_session;
	if session_id == nil then
		local expires = 60 * 60
		session_id = self.session_id
		self.ngx.header["Set-Cookie"] =
		string.format("session=%s; Path=/; Expires=%s", session_id, self.ngx.cookie_time(self.ngx.time() + expires))
	end
	local stored_access_token = self:get_access_token()
	local stored_refresh_token = self:get_refresh_token()
	if self.access_token ~= stored_access_token then
		if grantingAccessMethod(self.access_token) ~= 0 then
			self.terminate("Granting access method error!")
		else
			self:set_access_token(self.access_token)
		end
	end
	if self.refresh_token ~= stored_refresh_token then
		self:set_refresh_token(self.refresh_token)
	end
	return self
end

function SessionMgr:isValidSession()
	local session_id = self.ngx.var.cookie_session;
	if session_id ~= nil
			and session_id ~= self.session_id then
		self.terminate("Probable attempt of an attack - incorrect session id!")
	end
	return self
end

function SessionMgr:ifUnauthorizedAccess(terminate)
	self.terminate = terminate
	return self
end