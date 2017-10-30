local broadsock

local mock_socket = require "test.mock_socket"

return function()
	describe("broadsock server", function()

		before(function()
			package.loaded["broadsock.server.broadsock"] = nil
			broadsock = require "broadsock.server.broadsock"
			mock_socket.mock()
		end)
		after(function()
			mock_socket.unmock()
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
			assert(server_skt.ip == "*")
			assert(server_skt.port == 5000)
			assert(broadsock.client_count() == 0)

			server_skt.accept_queue[1] = socket.connect("127.0.0.1", 500)

			broadsock.update()
			assert(broadsock.client_count() == 1)
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


	end)
end
