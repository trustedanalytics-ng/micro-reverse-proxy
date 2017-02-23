--[[
 Copyright (c) 2017 Intel Corporation

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-- ]]

require "session-manager"
require "configuration"
require "tap-auth"
md5 = require "resty.md5"
jwt = require "resty.jwt"

MrpModule = {}
MrpModule.__index = MrpModule

setmetatable(MrpModule, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function MrpModule.new(ngx)
	local self = setmetatable({}, MrpModule)
	self.ngx = ngx
	return self
end

function MrpModule:initialize()
	local validators = require "resty.jwt-validators"
	local cjson = require "cjson"
	local config = Configuration():verify()
	local tap_auth = TapAuth(config, jwt, validators, cjson)
	tap_auth:setNgxContext(self.ngx)
	self.tap_auth = tap_auth
	self.config = config
	self.sessionMgr = SessionMgr(self.ngx, self.config)
	return self
end

function MrpModule:passRequest()
	-- declaration methods that will be used for authetnication/authorization
	-- and granting access process
	self:turnOnAuthTokensSharnig()
	:toAcquiringTokensUse(self.tap_auth:retriveTokensMethod())
	:toRefreshingTokensUse(self.tap_auth:refreshAccessTokenMethod())

	self:turnOnCheckingAccess()
	:toCheckTokensExpirationUse(self.tap_auth:checkExpirationMethod())
	:ifUnauthorizedAccess(self.tap_auth:terminateProcessingMethod())

	-- authentication/authorization/granting access sequence definition
	self.sessionMgr:initSession()
	:acquireTokens()

	self:triggerCheckingAccess()
	:refreshTokenIfExpired()

	self:turnOnKerberos()
end

function MrpModule:turnOnAuthTokensSharnig()
	assert(self.sessionMgr  ~= nil, "MrpModule must be initialized before using it!")
	if self.ngx.var.mrp_sharing_auth_tokens == "on" then
		self.sessionMgr:toStoreTokensUseMethods(self.tap_auth.writeAccessToken, self.tap_auth.writeRefreshToken)
	end
	return self.sessionMgr
end

function MrpModule:turnOnCheckingAccess()
	assert(self.sessionMgr  ~= nil, "MrpModule must be initialized before using it!")
	if self.ngx.var.mrp_authorization == "on" then
		self.sessionMgr:toCheckingAccessUse(self.tap_auth:checkIfAuthorizedMethod())
	end
	return self.sessionMgr
end

function MrpModule:triggerCheckingAccess()
	assert(self.sessionMgr  ~= nil, "MrpModule must be initialized before using it!")
	if self.ngx.var.mrp_authorization == "on" then
		self.sessionMgr:checkAccess()
	end
	return self.sessionMgr
end

function MrpModule:turnOnKerberos()
	assert(self.sessionMgr  ~= nil, "MrpModule must be initialized before using it!")
	if self.ngx.var.mrp_kerberos == "on" then
		self.sessionMgr:grantAccess(self.tap_auth.ktinit)
	else
		self.sessionMgr:grantAccess(function(token) return 0 end)
	end
	return self.sessionMgr
end