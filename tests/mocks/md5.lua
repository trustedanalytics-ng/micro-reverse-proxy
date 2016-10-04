local Md5Mock = {}

function Md5Mock:new()
	return Md5Mock
end

function Md5Mock:update(string)
end

function Md5Mock:final()
end

return Md5Mock
