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

local ngx = {
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
local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local cjson = require "cjson"

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
		self.tapAuthObject:setNgxContext(ngx)
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

	function TestTapAuth:testRefreshAccessToken_givenRefreshToken()
		local expected = {method = "POST",
			body = "grant_type=refresh_token&refresh_token=sdlsdlsd&client_id=nginx&client_secret=nginxsecret"}
		local ngx = {
			location = {
				capture = function(url, req)
					luaunit.assertEquals(url, "/oauth/token")
					luaunit.assertEquals(req, expected)
					return {status = 200, body = ""}
				end
			},
			req = {
				set_header = function(name, value)
					luaunit.assertEquals(name, "Content-Type")
					luaunit.assertEquals(value, "application/x-www-form-urlencoded;charset=utf-8")
				end
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
		local access_token = toTest:refreshAccessToken("sdlsdlsd")
		luaunit.assertEquals(access_token, "access")
	end

	function TestTapAuth:testRetriveCACertFromUaa_()
		local expected = {method = "GET", args = {}}
		local ngx = {
			location = {
				capture = function(url, req)
					luaunit.assertEquals(url, "/token_key")
					luaunit.assertEquals(req, expected)
					return {status = 200, body = ""}
				end
			},
			req = {
			},
			HTTP_GET = "GET",
			HTTP_OK = 200
		}
		local config = {
			client_secret = "nginxsecret",
			client_id = "nginx"
		}

		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		toTest:retriveCACertFromUaa()
	end

	function TestTapAuth:testRefreshAccessTokenMethod_mustReturnsFunction()
		luaunit.assertIsFunction(self.tapAuthObject:refreshAccessTokenMethod())
	end

	function TestTapAuth:testCheckIfAuthorizedMethod_mustReturnsFunction()
		local ngx = {
			shared = {
				public_key = {
					get = function(key) return "sdfsfsdfsdfsdf" end
				}
			}
		}
		local config = {}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		luaunit.assertIsFunction(toTest:checkIfAuthorizedMethod())
	end

	function TestTapAuth:testGetCACert_PkcachedInSharedDictReturnsPk()
		local ngx = {
			shared = {
				public_key = {
					get = function(key) return "public_key_value" end,
				}
			}
		}
		local config = {}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		local cacert = toTest:getCACert()
		luaunit.assertEquals(cacert, "public_key_value")
	end

	function TestTapAuth:testGetCACert_PkFromConfReturnsPk()
		local ngx = {
			shared = {
				public_key = {
					get = function(key) return "public_key_value" end,
					set = function(key, value) end
				}
			}
		}
		local config = {
			public_key = "public_key_value"
		}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		local cacert = toTest:getCACert()
		luaunit.assertEquals(cacert, "public_key_value")
	end

	function TestTapAuth:testGetCACert_PkFromUAAReturnsPk()
		local ngx = {
			shared = {
				public_key = {
					get = function(key) return nil end,
					set = function(key, value) end
				},
			},
			location = {
				capture = function(url, req)
					luaunit.assertEquals("/token_key", url)
					return {
						status = 200,
						body = nil
					}
				end
			},
			HTTP_OK = 200
		}
		local config = {
			public_key = nil
		}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest:setNgxContext(ngx)
		local cacert = toTest:getCACert()
		luaunit.assertEquals(cacert, "public_key_value")
	end

	function TestTapAuth:testWriteAccessToken_tokenWritenInFileOnFirstLine()
		local config = {
			public_key = nil
		}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest.writeAccessToken("some_access_token")
		local file = io.open(TapAuth.TEMP_DIR_PATH .. "/" .. TapAuth.ACCESS_TOKEN_FILE_NAME, "r")
		local actual = file:read()
		file:close()
		luaunit.assertEquals(actual, "some_access_token")
	end

	function TestTapAuth:testWriteRefreshToken_tokenWritenInFileOnFirstLine()
		local config = {
			public_key = nil
		}
		local toTest = TapAuth(config, jwt, validators, cjson)
		toTest.writeRefreshToken("some_refresh_token")
		local file = io.open(TapAuth.TEMP_DIR_PATH .. "/" .. TapAuth.REFRESH_TOKEN_FILE_NAME, "r")
		local actual = file:read()
		file:close()
		luaunit.assertEquals(actual, "some_refresh_token")
	end

os.exit(luaunit.LuaUnit.run())