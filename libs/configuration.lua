Configuration = {}
Configuration.__index = Configuration

setmetatable(Configuration, {
	__call = function (cls, ...)
		return cls.new(...)
	end,
})

function Configuration.new()
	assert(ngx.shared.session_store ~= nill, "Cant find session store configuration!!!!")
	assert(ngx.shared.public_key ~= nill, "Cant find public key store!!!!")

	local self = setmetatable({}, Configuration)
	self.public_key = os.getenv("JWT_PUBLIC_KEY")
	self.public_key_file = os.getenv("JWT_PUBLIC_KEY_FILE")
	self.uid = os.getenv("USER_ID")
	self.client_id = os.getenv("OAUTH_CLIENT_ID")
	self.client_secret = os.getenv("OAUTH_CLIENT_SECRET")
	self.session_seed = os.getenv("SESSION_ID_SEED")
	self.uaa = os.getenv("UAA_ADDRESS")

	return self
end