luaunit = require 'luaunit'
require 'tap-auth'
require 'configuration'
ngx = {
	log = function (statusCode, message) end,
	shared = {
		session_store = nil,
		public_key = nil
	}
}

TestConfiguration = {}
	function TestConfiguration:setUp()
		self.confObject = Configuration()
	end

	function TestConfiguration:testVerify_failure()
		luaunit:assertError(self.confObject.verify, self.confObject)
	end

TestTapAuth = {}

os.exit(luaunit.LuaUnit.run())
