local stream = require "broadsock.util.stream"

return function()
	-- http://lua-users.org/lists/lua-l/2013-08/msg00138.html
	local function comp_numbers(n1, n2)
		local epsilon = n1 * 0.00001
		return math.abs(n1 - n2) < epsilon * n2
	end

	describe("stream", function()
		it("should be able to serialize a number to an int32 and back again", function()
			local numbers = {
				{ number = 0, int32 = "\0\0\0\0" },
				{ number = 1, int32 = "\0\0\0\1" },
				{ number = 256, int32 = "\0\0\1\0" },
				{ number = 65536, int32 = "\0\1\0\0" },
				{ number = 16777216, int32 = "\1\0\0\0" },
				--{ number = 4294967295, int32 = "\255\255\255\255" },
			}

			for i=1,#numbers do
				local n = numbers[i]
				local int32 = stream.number_to_int32(n.number)
				assert(int32 == n.int32, ("Number %d should convert to %s but was %s"):format(n.number, stream.dump(n.int32), stream.dump(int32)))

				local number = stream.int32_to_number(int32)
				assert(number == n.number, ("int32 %s should convert to %d but was %d"):format(stream.dump(int32), n.number, number))
			end
		end)

		it("should be able to read and write a stream of mixed values", function()
			local str = stream.writer()
				.string("abcd")
				.number(1234)
				.vector3(vmath.vector3(10.05, 211.05, 2.0005))
				.quat(vmath.quat(10.05, 211.05, 2.0005, 1111.01))
				.bytes("foobar")
				.bytes("somecrapattheend")
				.tostring()

			local reader = stream.reader(str, #str)
			assert(reader.string() == "abcd")
			assert(reader.number() == 1234)
			local v3 = reader.vector3()
			assert(comp_numbers(v3.x, 10.05), ("Expected v3.x %f but got %f"):format(10.05, v3.x))
			assert(comp_numbers(v3.y, 211.05), ("Expected v3.y %f but got %f"):format(211.05, v3.y))
			assert(comp_numbers(v3.z, 2.0005), ("Expected v3.z %f but got %f"):format(2.0005, v3.z))
			local quat = reader.quat()
			assert(comp_numbers(quat.x, 10.05), ("Expected quat.x %f but got %f"):format(10.05, quat.x))
			assert(comp_numbers(quat.y, 211.05), ("Expected quat.y %f but got %f"):format(211.05, quat.y))
			assert(comp_numbers(quat.z, 2.0005), ("Expected quat.z %f but got %f"):format(2.0005, quat.z))
			assert(comp_numbers(quat.w, 1111.01), ("Expected quat.w %f but got %f"):format(1111.01, quat.w))
			local bytes = reader.bytes(6)
			assert(bytes == "foobar")

			assert(reader.rest() == "somecrapattheend")
			assert(reader.raw() == str)
			assert(reader.length() == #str)
		end)
	end)
end
