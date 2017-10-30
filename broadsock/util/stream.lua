local M = {}

function M.dump(bytes)
	local dmp = ""
	for i=1,#bytes do
		local b = bytes:byte(i)
		if (b >=32 and b <= 126) then
			dmp = dmp .. tostring(b) .. "[" .. string.char(b) .. "] "
		else
			dmp = dmp .. tostring(b) .. "[?] "
		end
	end
	dmp = dmp .. " (length: " .. #bytes .. ")"
	return dmp
end


--- Convert a Lua number to an int32 (4 bytes)
-- @param number The number to convert, only the integer part will be converted
-- @return String with 4 bytes representing the number
function M.number_to_int32(number)
	local b1 = bit.rshift(bit.band(number, 0xFF000000), 24)
	local b2 = bit.rshift(bit.band(number, 0x00FF0000), 16)
	local b3 = bit.rshift(bit.band(number, 0x0000FF00), 8)
	local b4 = bit.band(number, 0x000000FF)
	return string.char(b1, b2, b3, b4)
end

--- Convert an int32 to a Lua number
-- @param int32 String with 4 bytes representing a Lua number (integer part)
-- @param index Index into the string to read bytes from
-- @return Lua number
function M.int32_to_number(int32, index)
	index = index or 1
	local b1 = int32:byte(index + 0)
	local b2 = int32:byte(index + 1)
	local b3 = int32:byte(index + 2)
	local b4 = int32:byte(index + 3)
	return bit.bor(bit.lshift(b1, 24), bit.lshift(b2, 16), bit.lshift(b3, 8), b4)
end


--- Create a stream reader
-- @param str String to read from
-- @param str_length Length of string
-- @return Stream reader instance
function M.reader(str, str_length)
	local instance = {}

	local index = 1

	--- Read a string from the stream
	-- The string is represented by 4 bytes indicating the length, then followed
	-- by the actual characters of the string
	-- @return The string
	function instance.string()
		local length = M.int32_to_number(str, index)
		index = index + 4
		local s = str:sub(index, index + length - 1)
		index = index + length
		return s
	end

	--- Read a Lua number from the stream
	-- @return The number
	function instance.number()
		return tonumber(instance.string())
	end

	--- Read a Vector3 from the stream
	-- @return The vector3
	function instance.vector3()
		local x = instance.number()
		local y = instance.number()
		local z = instance.number()
		return vmath.vector3(x, y, z)
	end

	--- Read a Quaternion from the stream
	-- @return The quaternion
	function instance.quat()
		local x = instance.number()
		local y = instance.number()
		local z = instance.number()
		local w = instance.number()
		return vmath.quat(x, y, z, w)
	end

	--- Read a sequence of bytes from the stream
	-- @return The bytes
	function instance.bytes(count)
		assert(count, "You must provide a number of bytes to read")
		local s = str:sub(index, index + count - 1)
		index = index + count
		return s
	end

	--- Get the rest of the stream, ie anything not read yet, up until the length
	-- of the stream
	-- @return Remaining bytes in the stream
	function instance.rest()
		return str:sub(index, str_length), 1 + str_length - index
	end

	--- Get the raw bytes of the stream
	-- @return The entire stream of bytes
	function instance.raw()
		return str
	end

	--- Get the full length of the stream
	-- @return Length of the stream
	function instance.length()
		return str_length
	end

	return instance
end


--- Create a stream writer
-- @return Stream writer instance
function M.writer()
	local instance = {}

	local strings = {}

	function instance.clear()
		while #strings > 0 do
			table.remove(strings, #strings)
		end
	end

	--- Write a string to the stream
	-- A string is represented by 4 bytes indicating the length of the string,
	-- then followed by the actual string characters
	-- @param str The string to write
	-- @return The stream instance
	function instance.string(str)
		strings[#strings + 1] = M.number_to_int32(#str) .. str
		return instance
	end

	--- Write a Lua number to the stream
	-- The number is internally written as a string using tostring()
	-- @param number The number to write
	-- @return The stream instance
	function instance.number(number)
		local str = tostring(number)
		strings[#strings + 1] = M.number_to_int32(#str) .. str
		return instance
	end

	--- Write a vector3 to the stream
	-- The vector3 is internally written as three numbers (in turn represented as
	-- strings)
	-- @param v3 The vector3 to write
	-- @return The stream instance
	function instance.vector3(v3)
		instance.number(v3.x)
		instance.number(v3.y)
		instance.number(v3.z)
		return instance
	end

	--- Write a quaternion to the stream
	-- The quaternion is internally written as four numbers (in turn represented
	-- as strings)
	-- @param quat The quaternion to write
	-- @return The stream instance
	function instance.quat(quat)
		instance.number(quat.x)
		instance.number(quat.y)
		instance.number(quat.z)
		instance.number(quat.w)
		return instance
	end

	--- Writes bytes to the stream (raw, without appending length)
	-- @param bytes The bytes to write
	function instance.bytes(bytes)
		strings[#strings + 1] = bytes
		return instance
	end

	--- Convert the stream to a string, ready to send over a socket or written
	-- to disk
	-- @return The stream as a string
	function instance.tostring()
		return table.concat(strings, "")
	end

	return instance
end





return M
