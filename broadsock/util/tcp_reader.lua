local M = {}


--- Create a TCP socket reader
-- @param socket
-- @param on_data Function to call when data has been received
-- @return instance
-- @return error_message
function M.create(socket, on_data)
	assert(socket, "You must provide a socket")
	assert(on_data, "You must provide an on_data callback function")

	local instance = {}

	local connected = true

	-- receive bytes until specified number of bytes have
	-- been received or an error or a timeout happens
	local function receive(bytes)
		local received_data = ""
		while #received_data < bytes do
			local data, err, partial = socket:receive(bytes - #received_data)
			if data then
				received_data = received_data .. data
			elseif err == "closed" then
				connected = false
				error(err)
			elseif err == "timeout" then
				if partial then
					received_data = received_data .. partial
				end
				coroutine.yield()
			end
		end
		return received_data
	end

	local co = coroutine.create(function()
		while connected do
			local length_str = receive(4, true)
			local b1 = length_str:byte(1)
			local b2 = length_str:byte(2)
			local b3 = length_str:byte(3)
			local b4 = length_str:byte(4)
			local length = bit.lshift(b1, 24) + bit.lshift(b2, 16) + bit.lshift(b3, 8) + b4
			local data = receive(length)
			on_data(data, length)
		end
	end)

	--- Receive data on the socket
	-- It is up to the caller to ensure that the socket is readable
	-- @return success
	-- @return error_message Error message if receiving data failed for some reason
	function instance.receive()
		if coroutine.status(co) == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				connected = false
				print(err)
				return false, err
			end
		end
		return true
	end

	return instance
end


return M
