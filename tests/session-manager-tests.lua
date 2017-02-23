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

luaunit = require "luaunit"
require "session-manager"
require "tap-auth"
md5 = require "md5"
local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local cjson = require "cjson"


TestSessionManger = {}
	function TestSessionManger:testCreatingNewInstance_SessionStoreNotSet()
		local ngx = {}
		luaunit:assertError(SessionMgr.new , ngx, nil)
	end

	function TestSessionManger:testCreatingNewInstance_CorrectConfiguration()
		local ngx = {
			shared = {
				session_store = {}
			}
		}
		local config = {
			uid = "",
			session_seed = ""
		}

		local sessionMgr = SessionMgr(ngx, config)
		luaunit:assertIsTable(sessionMgr)
	end

  function TestSessionManger:testSessionValidation_incorrectSessionIdDetected_terminateProcessingReqest()
		local ngx = {
			shared = {
				session_store = {}
			},
			var = {
				cookie_session = "sdasd"
			},
			log = function(level, message)
				luaunit.assertEquals(message, "Probable attempt of an attack - incorrect session id!")
			end,
			exit = function(code)
				luaunit.assertEquals(code, 401)
			end,
			HTTP_UNAUTHORIZED = 401
		}
		local config = {}

		local tap_auth = TapAuth(config, jwt, validators, cjson)
		tap_auth:setNgxContext(ngx)
		local session = SessionMgr(ngx, config)
		session:ifUnauthorizedAccess(tap_auth:terminateProcessingMethod())
		       :initSession()
	end

	function TestSessionManger:testRefreshToken_accessTokenExpired_refreshTokeAction()
		local ngx = {
			shared = {
				session_store = {
					set = function(self, key, value) end,
					get = function(self, key) end
				}
			},
			var = {
				cookie_session = "sdasd"
			},
			log = function(level, message) end
		}
		local config = {}
		local refreshCallsNum = 0
		local tap_auth = TapAuth(config, jwt, validators, cjson)
		tap_auth:setNgxContext(ngx)
		local checkIfExpired = function(token)
			if ("jwt_access_token" == token) then
				return false
			end
			return true
		end
		local tokenAquisitonMethod = function() return "jwt_access_token", "jwt_refresh_token" end
		local tokenRefreshMethod = function(token)
			refreshCallsNum = refreshCallsNum + 1
			return token
		end
		SessionMgr(ngx, config):toAcquiringTokensUse(tokenAquisitonMethod)
		                       :toRefreshingTokensUse(tokenRefreshMethod)
		                       :toCheckTokensExpirationUse(checkIfExpired)
		                       :acquireTokens()
		                       :refreshTokenIfExpired()
		luaunit.assertEquals(refreshCallsNum, 1)
	end

	function TestSessionManger:testRefreshToken_accessTokenExpired_acquireTokensAction()
		local ngx = {
			shared = {
				session_store = {
					set = function(self, key, value) end,
					get = function(self, key) end
				}
			},
			var = {
				cookie_session = "sdasd"
			},
			log = function(level, message) end
		}
		local aquisitionCallsNum = 0
		local config = {}
		local tap_auth = TapAuth(config, jwt, validators, cjson)
		tap_auth:setNgxContext(ngx)
		local checkIfExpired = function(token) return false end
		local tokenAquisitonMethod = function()
			aquisitionCallsNum = aquisitionCallsNum + 1
			return "jwt_access_token", "jwt_refresh_token"
		end
		SessionMgr(ngx, config):toAcquiringTokensUse(tokenAquisitonMethod)
		                       :toCheckTokensExpirationUse(checkIfExpired)
		                       :acquireTokens()
		                       :refreshTokenIfExpired()
		luaunit.assertEquals(aquisitionCallsNum, 2)
	end

	function TestSessionManger:testAcquireOauthTokens_expectedAquisitionMethodCall()
		local ngx = {
			shared = {
				session_store = {
					set = function(self, key, value) end,
					get = function(self, key) end
				}
			},
			var = {
				cookie_session = nil
			},
			log = function(level, message) end
		}
		local config = {}
		local aquisitionCallsNum = 0
		local tokenAquisitonMethod = function()
			aquisitionCallsNum = aquisitionCallsNum + 1
			return "jwt_access_token", "jwt_refresh_token"
		end
		SessionMgr(ngx, config):toAcquiringTokensUse(tokenAquisitonMethod)
		                       :acquireTokens()
		luaunit.assertEquals(aquisitionCallsNum, 1)
	end

	function TestSessionManger:testGrantAccess_accesTokenNeedsToBeRefreshed()
		local actualTokenValue = {
			refresh_token = nil,
			access_token = nil
		}
		local ngx = {
			shared = {
				session_store = {
					set = function(self, key, value)
						actualTokenValue[key] = value
					end,
					get = function(self, key)
						if key == "access_token" then
							return "stored_access_token"
						elseif key == "access_token" then
							return "stored_access_token"
						end
					end
				}
			},
			var = {
				cookie_session = "sessionid"
			}
		}
		local config = {}
		local tokenAquisitonMethod = function()
			return "fresh_access_token", "fresh_refresh_token"
		end
		local grantingAccessCallsNum = 0
		local grantingAccessMethod = function()
			grantingAccessCallsNum = grantingAccessCallsNum + 1
			return 0
		end

		SessionMgr(ngx, config):toAcquiringTokensUse(tokenAquisitonMethod)
										       :acquireTokens()
										       :grantAccess(grantingAccessMethod)
		luaunit.assertEquals(actualTokenValue['refresh_token'], "fresh_refresh_token")
		luaunit.assertEquals(actualTokenValue['access_token'], "fresh_access_token")
		luaunit.assertEquals(grantingAccessCallsNum, 1)
	end

	function TestSessionManger:testCheckAccess_checkingAccessMethodMustBeCalled()
		local ngx = {
					shared = {
						session_store = {}
					},
					var = {
				cookie_session = "sessionid"
			}
		}
		local config = {}
		local checkAccessMethodCallsNum = 0
		local checkAccessMethod = function(token)
			checkAccessMethodCallsNum = checkAccessMethodCallsNum +1
			return true
		end
		SessionMgr(ngx, config):toCheckingAccessUse(checkAccessMethod)
		                       :checkAccess()
		luaunit.assertEquals(checkAccessMethodCallsNum, 1)
	end

os.exit(luaunit.LuaUnit.run())