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
	assert(ngx.shared.session_store ~= nill, "Can't find session store configuration!")
	assert(ngx.shared.public_key ~= nill, "Can't find public key store!")
	assert(self.uaa ~= nil, "I don't know where to find uaa? Not set UAA_ADDRESS!")
	assert(self.client_id ~= nil, "OAUTH_CLIENT_ID not set!")
	assert(self.client_secret ~= nil, "OAUTH_CLIENT_SECRET not set!")
	assert(self.session_seed ~= nil, "SESSION_ID_SEED not set!")

	return self
end