SessionMgr = {}
SessionMgr.__index = SessionMgr

setmetatable(SessionMgr, {
	__call = function (cls, ...)
		return cls.new(...)
end,
})

function SessionMgr.new(session_store, config)
	ngx.log(ngx.INFO, "Initiating session manager instance.")
	assert(session_store ~= nil, "Session store not set!")
	assert(config.session_seed ~= nil, "SESSION_ID_SEED env variable not set!")
	local self = setmetatable({}, SessionMgr)
	-- generating session id
	local md5Inst = md5:new()
	local str = require "resty.string"
	md5Inst:update(config.uid)
	md5Inst:update(config.session_seed)
	local digest = md5Inst:final()

	self.session_id = str.to_hex(digest)
	self.store = session_store
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

function SessionMgr:cookie()
	local session_id = ngx.var.cookie_session;
	if session_id == nil then
		local expires = 60 * 5 -- five minutes
		session_id = self.session_id
		ngx.header["Set-Cookie"] =
		string.format("session=%s; Path=/; Expires=%s",
			session_id,
			ngx.cookie_time(ngx.time() + expires))
	end
	return session_id
end

function SessionMgr:verify()
	local session_id = ngx.var.cookie_session;
	if session_id ~= nil
			and session_id ~= self.session_id then
		ngx.log(ngx.WARN, "Invalid authentication - incorrect session id!" .. self.session_id)
		ngx.exit(ngx.HTTP_UNAUTHORIZED)
	end
end