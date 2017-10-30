local tcp_writer = require "broadsock.util.tcp_writer"
local mock_socket = require "test.mock_socket"
local socket = require "builtins.scripts.socket"

return function()
	describe("tcp_writer", function()
		before(function()
			mock_socket.mock()
		end)
		after(function()
			mock_socket.unmock()
		end)

		it("should start empty", function()
			local writer = tcp_writer.create(socket.tcp())
			assert(writer.empty())
		end)

		it("should not be empty after adding data", function()
			local writer = tcp_writer.create(socket.tcp())
			writer.add("foo")
			assert(not writer.empty())
		end)

		it("should be empty after adding data and then clearing it", function()
			local writer = tcp_writer.create(socket.tcp())
			writer.add("foo")
			writer.clear()
			assert(writer.empty())
		end)

		it("should send all added data if no error occurs", function()
			local socket = socket.tcp()
			socket:connect("127.0.0.1", 5000)
			local writer = tcp_writer.create(socket)
			writer.add("foo")
			writer.add("bar")
			local ok, err = writer.send()
			assert(ok and not err)
			assert(socket.sent_data[1] == "foo")
			assert(socket.sent_data[2] == "bar")
			assert(writer.empty())
		end)


		it("should send all data in multiple calls when an error occurs", function()
			local socket = socket.tcp()
			socket:connect("127.0.0.1", 5000)
			socket.err = "timeout"
			local writer = tcp_writer.create(socket)
			writer.add("foobar")

			local ok, err = writer.send()
			assert(not ok and err)
			assert(#socket.sent_data == 1)

			socket.err = nil
			local ok, err = writer.send()
			assert(ok and not err)
			assert(#socket.sent_data == 2)

			assert(socket.sent_data[1] .. socket.sent_data[2] == "foobar")
			assert(writer.empty())
		end)

	end)
end
