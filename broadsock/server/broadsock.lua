local socket = require "builtins.scripts.socket"
local tcp_writer = require "broadsock.util.tcp_writer"
local tcp_reader = require "broadsock.util.tcp_reader"
local stream = require "broadsock.util.stream"


local M = {}

local clients = {}

local uid_sequence = 0

local server_socket

local function log(...)
	--print("[BROADSOCK SERVER]", ...)
end

local function tomessage(str)
	return stream.number_to_int32(#str) .. str
end

local function add_client(client)
	assert(client)
	log("add_client", client.uid)
	table.insert(clients, client)
end

local function remove_client(uid_to_remove)
	assert(uid_to_remove, "You must provide an uid")
	log("remove_client", uid_to_remove)
	for i=1,#clients do
		local client = clients[i]
		if client.uid == uid_to_remove then
			log("remove_client - removed")
			table.remove(clients, i)
			return
		end
	end
end

function M.client_count()
	return #clients
end

function M.send_message(client, message)
	assert(client, "You must provide a client")
	assert(message, "You must provide a message")
	log("send uid:", client.uid, "message:", message, "length:", #message)
	client.writer.add(message)
	client.writer.send()
end

function M.send_message_others(message, uid)
	assert(message, "You must provide a message")
	assert(uid, "You must provide a uid")
	--log("send_message_others", uid, message)
	for i=1,#clients do
		local client = clients[i]
		if client.uid ~= uid then
			M.send_message(client, message)
		end
	end
end

function M.send_message_all(message)
	assert(message, "You must provide a message")
	log("send_message_all", message)
	for i=1,#clients do
		local client = clients[i]
		M.send_message(client, message)
	end
end

function M.send_message_client(message, uid)
	assert(message, "You must provide a message")
	assert(uid, "You must provide a uid")
	log("send_message_client", uid, message)
	for i=1,#clients do
		local client = clients[i]
		if client.uid == uid then
			M.send_message(client, message)
			break
		end
	end
end

local function create_client(ip, uid, skt, data)
	assert(ip, "You must provide an ip")
	assert(uid, "you must provide an uid")
	assert(skt, "You must provide a socket")
	local client = {}
	client.ip = ip
	client.uid = uid
	client.data = data
	client.socket = skt
	client.writer = tcp_writer.create(skt)
	client.reader = tcp_reader.create(skt, function(message, length)
		M.handle_client_message(client, message)
	end)
	return client
end

function M.handle_client_message(client, message)
	assert(client, "You must provide a client")
	assert(message, "You must provide a message")
	log("handle_client_message", client.uid, stream.dump(message))
	local out = stream.writer().number(client.uid).bytes(message).tostring()
	M.send_message_others(tomessage(out), client.uid)
end

function M.handle_client_disconnected(client)
	assert(client, "You must provide a client")
	local disconnect_message = tomessage(
		stream.writer()
			.number(client.uid)
			.string("DISCONNECT")
			.tostring()
	)
	M.send_message_all(disconnect_message)

	remove_client(client.uid)
end

function M.handle_client_connected(ip, port, skt)
	assert(ip, "You must provide an ip")
	assert(port, "You must provide a port")
	assert(skt, "You must provide a socket")
	uid_sequence = uid_sequence + 1
	local client = create_client(ip, uid_sequence, skt, nil)
	add_client(client)

	local other_message = tomessage(
		stream.writer()
			.number(client.uid)
			.string("CONNECT_OTHER")
			.string(ip)
			.number(port)
			.tostring()
	)
	M.send_message_others(other_message, client.uid)

	local self_message = tomessage(
		stream.writer()
			.number(client.uid)
			.string("CONNECT_SELF")
			.tostring()
	)
	M.send_message(client, self_message)
	return client
end

--- Start the server. This will set up the server socket.
-- @param port The port to listen to connections on
-- @return success True on success, otherwise false
-- @return error Error message on failure, otherwise nil
function M.start(port)
	assert(port, "You must provide a port")
	log("Starting TCP server on port " .. port)
	local ok, err = pcall(function()
		local skt, err = socket.bind("*", port)
		assert(skt, err)
		server_socket = skt
		server_socket:settimeout(0)
	end)
	if not server_socket or err then
		log("Unable to start TCP server", err)
		return false, err
	end
	return true
end

--- Stop the server. This will close the server socket
-- and close any client connections
function M.stop()
	if server_socket then
		server_socket:close()
		server_socket = nil
	end
	while #clients > 0 do
		local client = table.remove(clients)
		client.socket:close()
	end
end

--- Update the server. The server will listen for new connections
-- and read from connected client sockets.
function M.update()
	if not server_socket then
		return
	end

	-- new connection?
	local client_socket, err = server_socket:accept()
	if client_socket then
		client_socket:settimeout(0)
		local client_ip, client_port = client_socket:getsockname()
		M.handle_client_connected(client_ip, client_port, client_socket)
	end

	-- incoming data?
	for _,client in ipairs(clients) do
		local ok, err = client.reader.receive()
		if not ok then
			log(err)
			M.handle_client_disconnected(client)
		end
	end
end

return M
