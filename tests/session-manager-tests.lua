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

  function TestSessionManger:testDoSome()
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
		       :isValidSession()
	end

os.exit(luaunit.LuaUnit.run())

