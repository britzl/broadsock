local M = {}

--- Create a TCP writer
-- @param socket The TCP client socket used when sending data
-- @param chunk_size The maximum size of any data that will be
-- sent. Defaults to 10000. If data is added that is larger than this value it will
-- be split into multiple "chunks". Note that there is no guarantee
-- that all data in a chunk is sent in a single call. Individual
-- chunks may still be split into multiple TCP send calls.
-- @return The created writer instance
function M.create(socket, chunk_size)
	assert(socket, "You must provide a TCP client")

	chunk_size = chunk_size or 10000

	local instance = {}

	local queue = {}

	function instance.clear()
		queue = {}
	end

	--- Add data to be sent on the next call to update()
	-- @param data Data to be sent
	function instance.add(data)
		assert(data, "You must provide some data")
		for i=1,#data,chunk_size do
			table.insert(queue, { data = data:sub(i, i + chunk_size - 1), sent_index = 0 })
		end
	end

	--- Send data over the socket
	-- It is up to the caller to make sure that the socket is writable
	-- @return success
	-- @return error_message
	function instance.send()
		while queue[1] do
			local first = queue[1]
			local sent_index, err, sent_index_on_err = socket:send(first.data, first.sent_index + 1, #first.data)
			if err then
				first.sent_index = sent_index_on_err
				return false, err
			end

			first.sent_index = sent_index
			if first.sent_index == #first.data then
				table.remove(queue, 1)
			end
		end
		return true
	end

	return instance
end


return M
