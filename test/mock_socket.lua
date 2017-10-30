local socket = require "builtins.scripts.socket"
local mock = require "deftest.mock"

local M = {}


local function mock_tcp_socket()
	local skt = {}
	skt.ip = nil
	skt.port = nil
	skt.timeout = nil
	skt.connected = false

	skt.err = nil
	skt.data = ""
	skt.sent_data = {}
	skt.received_data = {}

	skt.accept_queue = {}

	function skt.connect(self, address, port)
		skt.ip = address
		skt.port = port
		skt.connected = true
		return true
	end

	function skt.settimeout(self, timeout)
		skt.timeout = timeout
		return true
	end

	function skt.receive(self, bytes)
		if not skt.connected then
			return nil, "closed"
		elseif #skt.data < bytes then
			return nil, "timeout"
		elseif skt.err then
			bytes = math.min(math.random(2, bytes - 1), #skt.data)
			local partial = skt.data:sub(1, bytes)
			skt.data = skt.data:sub(bytes + 1)
			table.insert(skt.received_data, partial)
			return nil, skt.err, partial
		else
			local data = skt.data:sub(1, bytes)
			skt.data = skt.data:sub(bytes + 1)
			table.insert(skt.received_data, data)
			return data
		end
	end

	function skt.send(self, data, i, j)
		if not skt.connected then
			return nil, "closed"
		elseif skt.err then
			j = math.random(i, math.max(i, j - 1))
			table.insert(skt.sent_data, data:sub(i, j))
			return nil, skt.err, j
		else
			table.insert(skt.sent_data, data:sub(i, j))
			return j
		end
	end

	function skt.close(self)
		skt.connected = false
	end

	function skt.accept(self)
		local client = table.remove(skt.accept_queue, 1)
		if client then
			return client
		else
			return nil, "timeout"
		end
	end

	function skt.getsockname(self)
		return skt.ip, skt.port
	end

	mock.mock(skt)

	return skt
end

M.sockets = {}

function M.mock()
	mock.mock(socket)

	socket.tcp.replace(function()
		local skt = mock_tcp_socket()
		table.insert(M.sockets, skt)
		return skt
	end)

	socket.connect.replace(function(address, port, locaddr, locport, family)
		local skt = mock_tcp_socket()
		skt.ip = address
		skt.port = port
		skt.connected = true
		table.insert(M.sockets, skt)
		return skt
	end)

	socket.select.replace(function(sendt, recvt, timeout)
		local st = {}
		for i,skt in ipairs(sendt) do
			st[i] = skt
			st[skt] = true
		end
		local rt = {}
		for i,skt in ipairs(recvt) do
			rt[i] = skt
			rt[skt] = true
		end
		return st, rt
	end)

	socket.bind.replace(function(host, port, backlog)
		local skt = mock_tcp_socket()
		skt.ip = host
		skt.port = port
		skt.connected = true
		table.insert(M.sockets, skt)
		return skt
	end)
end

function M.unmock()
	mock.unmock(socket)
	M.sockets = {}
end



return M
