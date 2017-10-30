local broadsock

local mock_socket = require "test.mock_socket"
local mock = require "deftest.mock"

return function()
	describe("broadsock server", function()

		before(function()
			package.loaded["broadsock.server.broadsock"] = nil
			broadsock = require "broadsock.server.broadsock"
			mock_socket.mock()
			mock.mock(broadsock)
		end)
		after(function()
			mock_socket.unmock()
			mock.unmock(broadsock)
		end)

		it("should create a server socket when started", function()
			local ok, err = broadsock.start(5000)
			assert(ok and not err)
			local skt = mock_socket.sockets[1]
			assert(skt.ip == "*")
			assert(skt.port == 5000)
		end)


		it("should close the server socket when stopped", function()
			broadsock.start(5000)
			local skt = mock_socket.sockets[1]
			assert(skt)
			broadsock.stop()
			assert(skt.close.calls == 1)
		end)


		it("should accept incoming connections", function()
			local ok, err = broadsock.start(5000)
			assert(ok and not err)
			local server_skt = mock_socket.sockets[1]
			assert(server_skt)
			assert(broadsock.client_count() == 0)

			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)

			broadsock.update()
			assert(broadsock.client_count() == 1)
			assert(broadsock.handle_client_connected.calls == 1)
		end)
		

		it("should handle disconnecting clients", function()
			local clients = {}
			broadsock.handle_client_connected.replace(function(...)
				local client = broadsock.handle_client_connected.original(...)
				table.insert(clients, client)
				return client
			end)

			local ok, err = broadsock.start(5000)
			assert(ok and not err)
			local server_skt = mock_socket.sockets[1]
			assert(server_skt)

			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[2] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[3] = socket.connect("127.0.0.1", 500)
			broadsock.update()
			broadsock.update()
			broadsock.update()
			assert(broadsock.client_count() == 3)
			assert(#clients == 3)
			
			local calls = broadsock.send_message.calls
			broadsock.handle_client_disconnected(clients[1])
			assert(broadsock.send_message.calls == calls + 3, "Expected that a disconnect message was sent to each client")
			assert(broadsock.client_count() == 2)
		end)


		it("should broadcast an incoming message to all other clients", function()
			local clients = {}
			broadsock.handle_client_connected.replace(function(...)
				local client = broadsock.handle_client_connected.original(...)
				table.insert(clients, client)
				return client
			end)

			local ok, err = broadsock.start(5000)
			assert(ok and not err)
			local server_skt = mock_socket.sockets[1]
			assert(server_skt)

			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[2] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[3] = socket.connect("127.0.0.1", 500)
			broadsock.update()
			broadsock.update()
			broadsock.update()
			assert(broadsock.client_count() == 3)
			
			local calls = broadsock.send_message.calls
			broadsock.handle_client_message(clients[1], "foobar")
			assert(broadsock.send_message.calls == calls + 2, "Expected that a client message was sent to all other clients")
		end)
		


		it("should remove all connections when stopped", function()
			broadsock.start(5000)
			local server_skt = mock_socket.sockets[1]
			assert(server_skt)
			assert(broadsock.client_count() == 0)
			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)
			broadsock.update()
			assert(broadsock.client_count() == 1)
			broadsock.stop()
			assert(broadsock.client_count() == 0)
		end)


		it("should be able to send messages to connected clients", function()
			local clients = {}
			broadsock.handle_client_connected.replace(function(...)
				local client = broadsock.handle_client_connected.original(...)
				table.insert(clients, client)
				return client
			end)

			local ok, err = broadsock.start(5000)
			assert(ok and not err)
			local server_skt = mock_socket.sockets[1]
			assert(server_skt)

			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[2] = socket.connect("127.0.0.1", 500)
			server_skt.accept_queue[3] = socket.connect("127.0.0.1", 500)
			broadsock.update()
			broadsock.update()
			broadsock.update()
			assert(broadsock.client_count() == 3)
			assert(#clients == 3)
			
			-- send to all
			local calls = broadsock.send_message.calls
			broadsock.send_message_all("\0\0\0\2YO")
			assert(broadsock.send_message.calls == calls + 3, "Expected to be able to send a message to all clients")
			
			-- send to one
			calls = broadsock.send_message.calls
			broadsock.send_message_client("\0\0\0\2YO", clients[1].uid)
			assert(broadsock.send_message.calls == calls + 1, "Expected to be able to send a message to one client")
			
			-- send to all but one
			calls = broadsock.send_message.calls
			broadsock.send_message_others("\0\0\0\2YO", clients[1].uid)
			assert(broadsock.send_message.calls == calls + 2, "Expected to be able to send a message to all but one client")
		end)
		
	end)
end
