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

Configuration = {}
Configuration.__index = Configuration

setmetatable(Configuration, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function Configuration.new()
	local self = setmetatable({}, Configuration)
	self.public_key = os.getenv("JWT_PUBLIC_KEY")
	self.public_key_file = os.getenv("JWT_PUBLIC_KEY_FILE")
	self.uid = os.getenv("USER_ID")
	self.client_id = os.getenv("OAUTH_CLIENT_ID")
	self.client_secret = os.getenv("OAUTH_CLIENT_SECRET")
	self.session_seed = os.getenv("SESSION_ID_SEED")
	self.uaa = os.getenv("UAA_ADDRESS")
	self.uaaAuthorizationUri = os.getenv("UAA_AUTHORIZATION_URI")

	return self
end

function Configuration:verify()
	assert(ngx.shared.session_store ~= nil, "Can't find session store configuration!")
	assert(ngx.shared.public_key ~= nil, "Can't find public key store!")
	assert(self.uaa ~= nil, "I don't know where to find uaa? Not set UAA_ADDRESS!")
	assert(self.client_id ~= nil, "OAUTH_CLIENT_ID not set!")
	assert(self.client_secret ~= nil, "OAUTH_CLIENT_SECRET not set!")
	assert(self.session_seed ~= nil, "SESSION_ID_SEED not set!")

	return self
end