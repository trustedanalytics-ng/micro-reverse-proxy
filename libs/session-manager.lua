SessionMgr = {}
SessionMgr.__index = SessionMgr

setmetatable(SessionMgr, {
	__call = function (cls, ...)
		return cls.new(...)
end,
})

function SessionMgr.new(session_store, session_id)
	ngx.log(ngx.INFO, "Initiating session manager instance.")
	assert(session_store ~= nil, "Session store not set!")
	local self = setmetatable({}, SessionMgr)
	self.store = session_store
	self.session_id = session_id
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
