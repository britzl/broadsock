local M = {}


function M.number_to_int32(number)
	local b1 = bit.rshift(bit.band(number, 0xFF000000), 24)
	local b2 = bit.rshift(bit.band(number, 0x00FF0000), 16)
	local b3 = bit.rshift(bit.band(number, 0x0000FF00), 8)
	local b4 = bit.band(number, 0x000000FF)
	return string.char(b1, b2, b3, b4)
end

function M.int32_to_number(int32, index)
	local b1 = int32:byte(index + 0)
	local b2 = int32:byte(index + 1)
	local b3 = int32:byte(index + 2)
	local b4 = int32:byte(index + 3)
	return bit.lshift(b1, 24) + bit.lshift(b2, 16) + bit.lshift(b3, 8) + b4
end



function M.reader(str, str_length)
	local instance = {}

	local index = 1

	function instance.string()
		local length = M.int32_to_number(str, index)
		index = index + 4
		local s = str:sub(index, index + length - 1)
		index = index + length
		return s
	end

	function instance.number()
		return tonumber(instance.string())
	end

	function instance.vector3()
		local x = instance.number()
		local y = instance.number()
		local z = instance.number()
		return vmath.vector3(x, y, z)
	end

	function instance.quat()
		local x = instance.number()
		local y = instance.number()
		local z = instance.number()
		local w = instance.number()
		return vmath.quat(x, y, z, w)
	end
	
	function instance.rest()
		return str:sub(index, str_length), 1 + str_length - index
	end
	
	function instance.raw()
		return str
	end
	
	function instance.length()
		return str_length
	end

	return instance
end


function M.writer()
	local instance = {}

	local strings = {}

	function instance.string(str)
		strings[#strings + 1] = M.number_to_int32(#str) .. str
		return instance
	end

	function instance.number(number)
		local str = tostring(number)
		strings[#strings + 1] = M.number_to_int32(#str) .. str
		return instance
	end

	function instance.vector3(v3)
		instance.number(v3.x)
		instance.number(v3.y)
		instance.number(v3.z)
		return instance
	end

	function instance.quat(quat)
		instance.number(quat.x)
		instance.number(quat.y)
		instance.number(quat.z)
		instance.number(quat.w)
		return instance
	end

	function instance.tostring()
		return table.concat(strings, "")
	end

	return instance
end





return M
