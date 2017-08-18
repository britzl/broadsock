local socket = require "builtins.scripts.socket"
local tcp_send_queue = require "defnet.tcp_send_queue"
local tcp_reader = require "broadsock.util.tcp_reader"
local stream = require "broadsock.util.stream"


local M = {}


--- Create a broadsock instance
-- @param server_ip
-- @param server_port
-- @param on_custom_message
-- @param on_connected
-- @param on_disconnect
-- @return instance Instance or nil if something went wrong
-- @return error_message
function M.create(server_ip, server_port, on_custom_message, on_connected, on_disconnect)
	assert(server_ip, "You must provide a server IP")
	assert(server_port, "You must provide a server port")
	assert(on_custom_message, "You must provide an on_custom_message callback")
	assert(on_connected, "You must provide an on_connected callback")
	assert(on_disconnect, "You must provide an on_disconnect callback")
	local instance = {}

	local clients = {}

	local gameobjects = {}
	local gameobject_count = 0
	local remote_gameobjects = {}

	local factories = {}

	local go_uid_sequence = 0

	local uid = nil

	local connection = {
		socket = nil,
		send_queue = nil,
		socket_table = nil,
		connected = false,
	}


	local function add_client(uid_to_add)
		clients[uid_to_add] = { uid = uid_to_add }
		remote_gameobjects[uid_to_add] = {}
	end

	local function remove_client(uid_to_remove)
		clients[uid_to_remove] = nil
		for _,gameobject in pairs(remote_gameobjects[uid_to_remove]) do
			go.delete(gameobject.id)
		end
		remote_gameobjects[uid_to_remove] = nil
	end

	local function dump_data(data)
		local s = ""
		local i = 1
		while true do
			local length = stream.int32_to_number(data, i) i = i + 4
			local str = data:sub(i, i + length) i = i + length
			local foo = tostring(length) .. ":" .. tostring(str)
			print(tostring(length) .. ":" .. tostring(str))
			s  = s .. foo
			if data:byte(i) == nil then
				break
			end
		end
		return s
	end


	local function on_data(data, data_length)
		--dump_data(data)
		local sr = stream.reader(data, data_length)
		local from_uid = sr.number()
		local msg_id = sr.string()

		if msg_id == "GO" then
			if not clients[from_uid] then
				add_client(from_uid)
			end

			local remote_gameobjects_for_user = remote_gameobjects[from_uid]
			local count = sr.number()
			for _=1,count do
				local gouid = sr.string()
				local type = sr.string()

				local pos = sr.vector3()
				local rot = sr.quat()
				local scale = sr.vector3()
				if not remote_gameobjects_for_user[gouid] then
					local factory_url = factories[type]
					if factory_url then
						local id = factory.create(factory_url, pos, rot, {}, scale)
						remote_gameobjects_for_user[gouid] = { id = id, type = type }
					end
				else
					local id = remote_gameobjects_for_user[gouid].id
					local ok, err = pcall(function()
						go.set_position(pos, id)
						go.set_rotation(rot, id)
						go.set_scale(scale, id)
					end)
					if not ok then
						for k,v in pairs(remote_gameobjects_for_user) do
							print("   EXISTING REMOTE GO", k, v.id, v.type)
						end
					end
				end
			end
		elseif msg_id == "GOD" then
			if clients[from_uid] then
				local gouid = sr.string()
				local remote_gameobjects_for_user = remote_gameobjects[from_uid]
				local id = remote_gameobjects_for_user[gouid].id
				local ok, err = pcall(function()
					go.delete(id)
				end)
				if not ok then
					for k,v in pairs(remote_gameobjects_for_user) do
					end
				end
				remote_gameobjects_for_user[gouid] = nil
			end
		elseif msg_id == "CONNECT_OTHER" then
			print("CONNECT")
			add_client(from_uid)
		elseif msg_id == "CONNECT_SELF" then
			print("CONNECT")
			add_client(from_uid)
			uid = from_uid
			on_connected()
		elseif msg_id == "DISCONNECT" then
			print("DISCONNECT")
			remove_client(from_uid)
		else
			print("CUSTOM MESSAGE", msg_id)
			local message_data, message_length = sr.rest()
			on_custom_message(msg_id, from_uid, stream.reader(message_data, message_length))
		end
	end

	--- Register a game object with the instance
	-- The game object transform will from this point on be sent to the server
	-- and broadcast to any other client
	-- @param id Id of the game object
	-- @param type Type of game object. Must match a known factory type
	function instance.register_gameobject(id, type)
		assert(id, "You must provide a game object id")
		assert(type and factories[type], "You must provide a known game object type")
		go_uid_sequence = go_uid_sequence + 1
		local gouid = tostring(uid) .. "_" .. go_uid_sequence
		gameobjects[gouid] = { id = id, type = type, gouid = gouid }
		gameobject_count = gameobject_count + 1
	end

	--- Unregister a game object
	-- The game object will no longer send its transform
	-- This will result in a message to the server to notify connected clients
	-- that the game object has been removed
	-- @param id Id of the game object
	function instance.unregister_gameobject(id)
		for gouid,gameobject in pairs(gameobjects) do
			if gameobject.id == id then
				gameobjects[gouid] = nil
				gameobject_count = gameobject_count - 1
				instance.send(stream.writer().string("GOD").string(gouid).tostring())
				return
			end
		end
		error("Unable to find game object")
	end

	--- Register a factory and associate it with a game object type
	-- The factory will be used to create game objects that have been spawned
	-- by a remote client
	-- @param url URL of the factory
	-- @param type Game object type
	function instance.register_factory(url, type)
		assert(url, "You must provide a factory URL")
		assert(type, "You must provide a game object type")
		factories[type] = url
	end



	--- Send data to the broadsock server
	-- Note: The data will actually not be sent until update() is called
	-- @param data
	function instance.send(data)
		if connection.connected then
			connection.send_queue.add(stream.number_to_int32(#data) .. data)
		end
	end

	--- Update the broadsock client instance
	-- Any registered game objects will send their transforms
	-- This will also send any other queued data
	function instance.update()
		if connection.connected then
			local sw = stream.writer()
			sw.string("GO")
			sw.number(gameobject_count)
			for gouid,gameobject in pairs(gameobjects) do
				local pos = go.get_position(gameobject.id)
				local rot = go.get_rotation(gameobject.id)
				local scale = go.get_scale(gameobject.id)
				sw.string(gouid)
				sw.string(gameobject.type)
				sw.vector3(pos)
				sw.quat(rot)
				sw.vector3(scale)
			end
			instance.send(sw.tostring())

			-- check if the socket is ready for reading and/or writing
			local receivet, sendt = socket.select(connection.socket_table, connection.socket_table, 0)

			if sendt[connection.socket] then
				local ok, err = connection.send_queue.send()
				if not ok and err == "closed" then
					instance.destroy()
					on_disconnect()
					return
				end
			end

			if receivet[connection.socket] then
				local ok, err = connection.reader.receive()
				if not ok then
					instance.destroy()
					on_disconnect()
					return
				end
			end
		end
	end

	--- Destroy this broadsock instance
	-- Nothing can be done with the instance after this call
	function instance.destroy()
		if connection.connected then
			connection.socket:close()
			connection.socket = nil
			connection.send_queue = nil
			connection.reader = nil
			connection.socket_table = nil
			connection.connected = false
		end
	end



	local ok, err = pcall(function()
		connection.socket = socket.tcp()
		assert(connection.socket:connect(server_ip, server_port))
		assert(connection.socket:settimeout(0))
		connection.socket_table = { connection.socket }
		connection.send_queue = tcp_send_queue.create(connection.socket, M.TCP_SEND_CHUNK_SIZE)
		connection.reader = tcp_reader.create(connection.socket, on_data)
	end)
	if not ok or not connection.socket or not connection.send_queue then
		print("tcp_client.create() error", err)
		return nil, ("Unable to connect to %s:%d"):format(server_ip, server_port)
	end
	connection.connected = true

	return instance
end


return M
