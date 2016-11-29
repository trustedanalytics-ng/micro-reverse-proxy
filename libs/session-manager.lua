SessionMgr = {}
SessionMgr.__index = SessionMgr

setmetatable(SessionMgr, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

--[[
 Creates new session manager instance.

 @param context, nginx context from nginx.config. ngx global
 @param config, configuration, instance of Configuration type

 @returns reference to created SessionMgr
-- ]]
function SessionMgr.new(context, config)
	assert(context.shared.session_store ~= nil, "Session store not set! Set lua_shared_dict session_store ***;")
	local self = setmetatable({}, SessionMgr)
	self.session_id = self:createSessionId(config)
	self.store = context.shared.session_store
	self.ngx = context
	self.access_token = nil
	self.refresh_token = nil

	self.terminate = function(message) print(message); os.exit(1) end
	self.tokensAquisitionMethod =      function() self.terminate("Provide tokensAquisitionMethod "
			                                                         .. "i.e:toAcquiringTokensUse("
			                                                         .. "function() return  {nil, nil} end)")end
	self.authorizationMethod =         function(token) self.terminate("Provide authorizationMethod "
			                                                              .."i.e:toCheckAccessUse("
			                                                              .. "function(token) return true end)")end
	self.checkExpirationTokensMethod = function(token) self.terminate("Provide checkExpirationTokensMethod "
	                                                                  .. "i.e:toCheckTokensExpirationUse("
			                                                              .. "function(token) return true end)")end
	self.accessTokenRefreshMethod =    function(token) self.terminate("Provide accessTokenRefreshMethod"
			                                                              .. "i.e:toRefreshingTokensUse("
			                                                              .. "function(refresh_token) return access_token")end
	self.accessTokenStoringMethod = nil
	self.refreshTokenStoringMethod = nil
	return self
end

--[[
  Registers callback function executed in case of unauthorized attempt
  of access detection.

  @param terminate, function pointer default implementation:
                    function(message)
                      print(message)
                      os.exit()
                    end

  @returns self reference
-- ]]
function SessionMgr:ifUnauthorizedAccess(terminate)
	self.terminate = terminate
	return self
end

--[[
  Registers callback functions that will be called for access/refresh tokens
  storing.

	@param accessTokenStoringMethod, function pointer i.e:
	                                 function(token) ..storing token logic.. end
	@param refreshTokenStoringMethod, function pointer i.e:
	                                  function(token) ..storing token logic.. end

  @returns self reference
-- ]]
function SessionMgr:toStoreTokensUseMethods(accessTokenStoringMethod, refreshTokenStoringMethod)
	self.accessTokenStoringMethod = accessTokenStoringMethod
	self.refreshTokenStoringMethod = refreshTokenStoringMethod
	return self
end

--[[
  Registers callback function executed for access/refresh tokens obtaining.

  @param aquisitionMethod, function pointer i.e:
                           function()
                              .. obtainig tokens logic ..
                              return  {"access_token_value", "refresh_token_value"}
                           end

  @returns self reference
-- ]]
function SessionMgr:toAcquiringTokensUse(aquisitionMethod)
	self.tokensAquisitionMethod = aquisitionMethod
	return self
end

--[[
  Registers callback function executed in case of access token expired. It should provide
  refreshing access token logic using refresh token.

  @param refreshMethod, function pointer i.e:
                        function(refresh_token)
                           .. refreshig access token logic ..
                           return access_token
                        end

  @returns self reference
-- ]]
function SessionMgr:toRefreshingTokensUse(refreshMethod)
	self.accessTokenRefreshMethod = refreshMethod
	return self
end

--[[
  Registers callback function that provides authorization logic.

  @param aquisitionMethod, function pointer i.e:
                           function(token) return true end

  @returns self reference
-- ]]
function SessionMgr:toCheckingAccessUse(checkingAccessMethod)
	self.authorizationMethod = checkingAccessMethod
	return self
end

--[[
  Registers callback function that is used for token's "freshness"
  checking.

  @param checkIfNotExpired, function pointer i.e:
                            function(token) return true end

  @returns self reference
-- ]]
function SessionMgr:toCheckTokensExpirationUse(checkIfNotExpired)
	self.checkExpirationTokensMethod = checkIfNotExpired
	return self
end

--[[
   Initialize a session.

   @returns self reference
-- ]]
function SessionMgr:initSession()
	local session_id = self.ngx.var.cookie_session;
	if session_id ~= nil
			and session_id ~= self.session_id then
		self.terminate("Probable attempt of an attack - incorrect session id!")
	end
	return self
end

--[[
   Acquires access/refresh the tokens. Stores obtained tokens in the session.

   @returns self reference
-- ]]
function SessionMgr:acquireTokens()
	local session_id = self.ngx.var.cookie_session;
	self.access_token = self:get_access_token();
	self.refresh_token = self:get_refresh_token();
	if self.access_token == nil or
			self.refresh_token == nil or
			session_id == nil then
		  self.access_token,self.refresh_token = self.tokensAquisitionMethod()
	end
	return self
end

--[[
   Executes authorization logic. Checks If tokens stored in session
   gives the access?

   @returns self reference
-- ]]
function SessionMgr:checkAccess()
	if not self.authorizationMethod(self.access_token) then
		self.terminate("Not authorized access attempt!")
	end
	return self
end

--[[
   Refreshes access token if it expired. Executes acquiting tokens logic
   in case of refresh token expiration.

   @returns self reference
-- ]]
function SessionMgr:refreshTokenIfExpired()
	if not self.checkExpirationTokensMethod(self.access_token) then
		self.ngx.log(self.ngx.INFO, "Access token expired! " .. self.access_token)
		if not self.checkExpirationTokensMethod(self.refresh_token) then
			self.ngx.log(self.ngx.INFO, "Refresh token expired. " .. self.refresh_token)
			self.access_token,self.refresh_token = self.tokensAquisitionMethod()
		else
			self.ngx.log(self.ngx.INFO, "Refreshing access token using refresh token! " .. self.refresh_token)
			self.access_token = self.accessTokenRefreshMethod(self.refresh_token)
		end
	end
	return self
end

--[[
   Granting access action. Calls grantingAccessMethod.

   @param grantingAccessMethod, function pointer i.e:
                           function(token)
                             if .. granting access failed .. then
                               return 1
                              end
                              return 0
                           end

   @returns self reference
-- ]]
function SessionMgr:grantAccess(grantingAccessMethod)
	return self:replaceStoredTokens(grantingAccessMethod)
	           :sessionExpiresAfter(60 * 60)
end

function SessionMgr:set_access_token(token)
	local succ, err, forcible = self.store:set("access_token", token)
	if succ and
			self.accessTokenStoringMethod ~= nil then
		self.accessTokenStoringMethod(token)
	end
end

function SessionMgr:get_access_token()
	local value, flags = self.store:get("access_token")
	return value
end

function SessionMgr:set_refresh_token(token)
	local succ, err, forcible = self.store:set("refresh_token", token)
	if succ and
			self.refreshTokenStoringMethod ~= nil then
		self.refreshTokenStoringMethod(token)
	end
end

function SessionMgr:get_refresh_token()
	local value, flags = self.store:get("refresh_token")
	return value
end

function SessionMgr:get_session_id()
	return self.session_id
end

function SessionMgr:replaceStoredTokens(grantingAccessMethod)
	local stored_access_token = self:get_access_token()
	local stored_refresh_token = self:get_refresh_token()
	if self.access_token ~= stored_access_token then
		if grantingAccessMethod(self.access_token) ~= 0 then
			self.terminate("Granting access method call treminated with error!")
		else
			self:set_access_token(self.access_token)
		end
	end
	if self.refresh_token ~= stored_refresh_token then
		self:set_refresh_token(self.refresh_token)
	end
	return self
end

function SessionMgr:sessionExpiresAfter(expirationTime)
	local session_id = self.ngx.var.cookie_session;
	if session_id == nil then
		session_id = self.session_id
		self.ngx.header["Set-Cookie"] =
		string.format("session=%s; Path=/; Expires=%s",
			session_id,
			self.ngx.cookie_time(self.ngx.time() + expirationTime))
	end
	return self
end

function SessionMgr:createSessionId(config)
	local md5Inst = md5:new()
	local str = require "resty.string"
	if config.uid ~= nil then
		md5Inst:update(config.uid)
	end
	md5Inst:update(config.session_seed)
	local digest = md5Inst:final()
	return str.to_hex(digest)
end