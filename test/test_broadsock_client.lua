local broadsock

local mock_socket = require "test.mock_socket"

return function()
	describe("broadsock client", function()

		local function nop() end

		before(function()
			package.loaded["broadsock.client.broadsock"] = nil
			broadsock = require "broadsock.client.broadsock"
			mock_socket.mock()
		end)
		after(function()
			mock_socket.unmock()
		end)


		it("should connect successfully when created", function()
			local client, err = broadsock.create("127.0.0.1", 5000, nop, nop, nop)
			assert(client and not err)
			local skt = mock_socket.sockets[1]
			assert(skt.ip == "127.0.0.1")
			assert(skt.port == 5000)
		end)

		it("should be possible to register factories", function()
			local client, err = broadsock.create("127.0.0.1", 5000, nop, nop, nop)
			assert(client and not err)
			local factory_url = msg.url("/factories#type1")
			client.register_factory(factory_url, "type1")
			assert(client.has_factory("type1"))
			assert(client.get_factory_url("type1") == factory_url)
		end)

		it("should be possible to register and unregister game objects", function()
			local client, err = broadsock.create("127.0.0.1", 5000, nop, nop, nop)
			assert(client and not err)
			client.register_factory(msg.url("/factories#type1"), "type1")
			client.register_factory(msg.url("/factories#type2"), "type2")
			client.register_gameobject("/type1", "type1")
			client.register_gameobject("/type2", "type2")
			assert(client.gameobject_count() == 2)
		end)

		it("should send information about registered game objects every update", function()
			local client, err = broadsock.create("127.0.0.1", 5000, nop, nop, nop)
			assert(client and not err)

			local skt = mock_socket.sockets[1]
			socket.select.replace(function(sndt,rcvt,timeout)
				return {}, { [skt] = true }
			end)

			client.register_factory(msg.url("/factories#type1"), "type1")
			client.register_factory(msg.url("/factories#type2"), "type2")
			client.register_gameobject("/type1", "type1")
			client.register_gameobject("/type2", "type2")
			client.update()
			assert(skt.sent_data[1] and skt.sent_data[1]:sub(9,10) == "GO")
			assert(not skt.sent_data[2])
			client.update()
			assert(skt.sent_data[2] and skt.sent_data[2]:sub(9,10) == "GO")
		end)
	end)
end
