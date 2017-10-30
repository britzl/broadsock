local broadsock_client
local broadsock_server

local mock = require "deftest.mock"
local mock_factory = require "test.mock_factory"

return function()
	describe("broadsock client and server", function()

		local function create_callbacks()
			local callbacks = {}
			function callbacks.on_custom_message() end
			function callbacks.on_connected() end
			function callbacks.on_disconnect() end
			mock.mock(callbacks)
			return callbacks
		end

		local function nop() end

		before(function()
			package.loaded["broadsock.client.broadsock"] = nil
			package.loaded["broadsock.server.broadsock"] = nil
			broadsock_client = require "broadsock.client.broadsock"
			broadsock_server = require "broadsock.server.broadsock"
			--mock_socket.mock()
			mock_factory.mock()
		end)
		after(function()
			--mock_socket.unmock()
			mock_factory.unmock()
			broadsock_server.stop()
		end)

		it("should connect clients and let them know of each other", function()
			local ok, err = broadsock_server.start(5000)
			assert(ok and not err)
			local callbacks1 = create_callbacks()
			local client1, err = broadsock_client.create("127.0.0.1", 5000, callbacks1.on_custom_message, callbacks1.on_connected, callbacks1.on_disconnect)
			assert(client1 and not err)

			local callbacks2 = create_callbacks()
			local client2, err = broadsock_client.create("127.0.0.1", 5000, callbacks2.on_custom_message, callbacks2.on_connected, callbacks2.on_disconnect)
			assert(client2 and not err)

			-- handle the client1 and client2 connections
			broadsock_server.update()	-- handle client1 connect
			assert(broadsock_server.client_count() == 1)
			broadsock_server.update()	-- handle client2 connect
			assert(broadsock_server.client_count() == 2)

			-- update the first client
			-- it will receive a CONNECT_SELF and a CONNECT_OTHER
			client1.update()
			assert(callbacks1.on_connected.calls == 1)
			assert(client1.client_count() == 2)

			-- update the second client
			-- it will receive a CONNECT_SELF but no CONNECT_OTHER since when
			-- the first client was created and connected the server didn't
			-- know of any other clients and could thus not send a CONNECT_OTHER
			-- message
			client2.update()
			assert(callbacks2.on_connected.calls == 1)
			assert(client2.client_count() == 1)
		end)


		it("should send game object positions to other clients", function()
			local ok, err = broadsock_server.start(5000)
			assert(ok and not err)
			local callbacks1 = create_callbacks()
			local client1, err = broadsock_client.create("127.0.0.1", 5000, callbacks1.on_custom_message, callbacks1.on_connected, callbacks1.on_disconnect)
			assert(client1 and not err)

			local callbacks2 = create_callbacks()
			local client2, err = broadsock_client.create("127.0.0.1", 5000, callbacks2.on_custom_message, callbacks2.on_connected, callbacks2.on_disconnect)
			assert(client2 and not err)

			client1.register_factory("/factories#type1", "type1")
			client2.register_factory("/factories#type1", "type1")
			local id1 = factory.create("/factories#type1", vmath.vector3(100, 100, 0))
			client1.register_gameobject(id1, "type1")

			local id2 = factory.create("/factories#type1", vmath.vector3(200, 200, 0))
			client2.register_gameobject(id2, "type1")

			broadsock_server.update()	-- handle client1 connect
			broadsock_server.update()	-- handle client2 connect
			client1.update()			-- connected, send position of go
			client2.update()			-- connected, send position of go
			broadsock_server.update()	-- receive positions, send to others
			client1.update()			-- receive other go
			client2.update()			-- receive other go

			assert(#mock_factory.ids == 4)
		end)



	end)
end
