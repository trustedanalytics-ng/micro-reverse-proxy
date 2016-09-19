luaunit = require "luaunit"

ngx = {
	var = {
		arg_code = nil
	},
	location = {
		capture = nil
	},
	redirect = nil,
	log = function(statusCode, message) end,
	shared = {
		session_store = nil,
		public_key = nil
	},
	HTTP_POST = "POST",
	HTTP_OK = 200,
	HTTP_REQUEST_TIMEOUT = 408,
	HTTP_BAD_REQUEST = 400,
	HTTP_UNAUTHORIZED = 401,
	exit = function(message) end
}

require "tap-auth"
require "configuration"
jwt = require "resty.jwt"
validators = require "resty.jwt-validators"
cjson = require "cjson"
md5 = require "resty.md5"

TestConfiguration = {}
	function TestConfiguration:setUp()
		self.confObject = Configuration()
	end

	function TestConfiguration:testVerify_failure()
		luaunit:assertError(self.confObject.verify, self.confObject)
	end

TestTapAuth = {}
	function TestTapAuth:setUp()
		local config = {
			uaaAuthorizationUri = "http://login.uaa.jojo/oauth/authorize",
			client_id = "jojo",
			uaa = "http://uaa.jojo"
		}
		self.tapAuthObject = TapAuth(config, jwt, validators, cjson)
	end

	function TestTapAuth:testJsonRespDecode_HTTP_OK_status_reponse()
		-- given
		local httpResp = {
			status = ngx.HTTP_OK,
			body = nil
		}
		--when
		local resp = self.tapAuthObject:jsonRespDecode(httpResp)

		--then
		luaunit.assertEquals(resp.access_token, "access")
		luaunit.assertEquals(resp.refresh_token, "refresh")
	end

	function TestTapAuth:testJsonRespDecode_HTTP_REQUEST_TIMEOUT_status_reponse()
		-- given
		local httpResp = {
			status = ngx.HTTP_REQUEST_TIMEOUT,
			body = nil
		}

		--then
		luaunit:assertError(self.tapAuthObject.jsonRespDecode, self.tapAuthObject, httpResp)
	end

	function TestTapAuth:testJsonRespDecode_HTTP_UNAUTHORIZED_status_reponse()
		-- given
		local httpResp = {
			status = ngx.HTTP_UNAUTHORIZED,
			body = nil
		}

		--then
		luaunit:assertError(self.tapAuthObject.jsonRespDecode, self.tapAuthObject, httpResp)
	end

	function TestTapAuth:testRetriveTokens_authorizationUriIsSet()
		-- given
		local config = {
			uaaAuthorizationUri = "http://login.uaa.jojo/oauth/authorize",
			client_id = "jojo",
			uaa = "http://uaa.jojo"
		}
		local expected = "http://login.uaa.jojo/oauth/authorize?client_id=jojo&response_type=code"
		local ngx = {
			var = {
				arg_code = nil
			},
			redirect = function(actual) luaunit.assertEquals(actual, expected) end
		}

		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)

		-- when
		toTest:retriveTokens()
	end

	function TestTapAuth:testRetriveTokens_authorizationUriIsNil()
		-- given
		local config = {
			uaaAuthorizationUri = nil,
			client_id = "jojo",
			uaa = "http://uaa.jojo"
		}
		local expected = "http://uaa.jojo/oauth/authorize?client_id=jojo&response_type=code"
		local ngx = {
			var = {
				arg_code = nil
			},
			redirect = function(actual) luaunit.assertEquals(actual, expected) end
		}

		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)

		--when
		toTest:retriveTokens()
	end

	function TestTapAuth:testRetriveTokens_redirectedFromUaaWithAuthCode()
		local ngx = {
			var = {
				arg_code = "sdsdsd"
			},
			location = {
				capture = function(url, req)
					return {status = 200, body = ""}
				end
			},
			req = {
				set_header = function(name, value) end
			},
			HTTP_POST = "POST",
			HTTP_OK = 200
		}
		local config = {
			client_secret = "nginxsecret",
			client_id = "nginx"
		}

		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		local access, refresh = toTest:retriveTokens()
		luaunit.assertEquals(access, "access")
		luaunit.assertEquals(refresh, "refresh")
	end

os.exit(luaunit.LuaUnit.run())