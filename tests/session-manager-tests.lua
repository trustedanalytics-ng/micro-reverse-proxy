luaunit = require "luaunit"
require "session-manager"
md5 = require "md5"

TestSessionManget = {}
	function TestSessionManget:testCreatingNewInstance_SessionStoreNotSet()
		local ngx = {}
		luaunit:assertError(SessionMgr.new , ngx, nil)
	end

	function TestSessionManget:testCreatingNewInstance_CorrectConfiguration()
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

os.exit(luaunit.LuaUnit.run())

