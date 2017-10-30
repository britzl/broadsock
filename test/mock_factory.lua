local mock = require "deftest.mock"

local M = {}

M.ids = nil

function M.mock()
	M.ids = {}
	mock.mock(factory)
	factory.create.replace(function(url, pos, ...)
		local id = factory.create.original(url, pos, ...)
		table.insert(M.ids, { url = url, pos = pos, id = id })
		return id
	end)
end


function M.unmock()
	mock.unmock(factory)
	for _,data in ipairs(M.ids) do
		go.delete(data.id)
	end
	M.ids = nil
end


return M
