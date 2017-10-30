local tcp_reader = require "broadsock.util.tcp_reader"
local mock_socket = require "test.mock_socket"
local socket = require "builtins.scripts.socket"

return function()
	describe("tcp_reader", function()
		before(function()
			mock_socket.mock()
		end)
		after(function()
			mock_socket.unmock()
		end)

		it("should receive data as long as it is connected", function()
			local skt = socket.tcp()
			skt:connect("127.0.0.1", 5000)
			skt.data = "\0\0\0\10abcdefghij\0\0\0\3foo"

			local reader = tcp_reader.create(skt, function() end)
			reader.receive()
			assert(skt.received_data[2] == "abcdefghij")
			assert(skt.received_data[4] == "foo")
		end)

	end)
end
