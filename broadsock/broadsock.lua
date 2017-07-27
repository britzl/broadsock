local tcp_client = require "defnet.tcp_client"
local b64 = require "broadsock.b64"
local rxijson = require "broadsock.rxijson"
json.encode = rxijson.encode


local M = {}

function M.create(ip, port, on_disconnect)
	local instance = {}

	local clients = {}

	local gameobjects = {}
	local remote_gameobjects = {}

	local factories = {}

	local go_uid_count = 0

	local uid = nil

	local function add_client(uid)
		clients[uid] = { uid = uid }
		remote_gameobjects[uid] = {}
	end

	local function remove_client(uid)
		clients[uid] = nil
		for _,gameobject in pairs(remote_gameobjects[uid]) do
			go.delete(gameobject.id)
		end
		remote_gameobjects[uid] = nil
	end

	local function on_data(json_data)
		local ok, message = pcall(json.decode, json_data)
		if not ok then
			return
		end

		if message.event == "DATA" then
			if not clients[message.uid] then
				add_client(message.uid)
			end

			local data = json.decode(b64.decode(message.data))
			if data.action == "GO" then
				local remote_gameobjects_for_user = remote_gameobjects[message.uid]
				for _,gameobject in pairs(data.objects) do
					local gouid = gameobject.gouid
					if gameobject.deleted then
						go.delete(remote_gameobjects_for_user[gouid].id)
						remote_gameobjects_for_user[gouid] = nil
					else
						local type = gameobject.type
						local pos = vmath.vector3(gameobject.px, gameobject.py, gameobject.pz)
						local rot = vmath.quat(gameobject.rx, gameobject.ry, gameobject.rz, gameobject.rw)
						local scale = vmath.vector3(gameobject.sx, gameobject.sy, gameobject.sz)
						if not remote_gameobjects_for_user[gouid] then
							local id = factory.create(factories[type], pos, rot, {}, scale)
							remote_gameobjects_for_user[gouid] = { id = id }
						else
							local id = remote_gameobjects_for_user[gouid].id
							go.set_position(pos, id)
							go.set_rotation(rot, id)
							go.set_scale(scale, id)
						end
					end
				end
			end

		elseif message.event == "CONNECT" then
			print("CONNECT")
			if not message.ip then
				uid = message.uid
			end
			add_client(message.uid)
		elseif message.event == "DISCONNECT" then
			print("DISCONNECT")
			remove_client(message.uid)
		end
	end

	local client, err = tcp_client.create(ip, port, on_data, on_disconnect)
	if err then
		return nil, err
	end

	function instance.send(data)
		if client then
			client.send(data)
		end
	end

	function instance.update()
		if client then
			local message = { action = "GO", objects = {} }
			for gouid,gameobject in pairs(gameobjects) do
				local pos = go.get_position(gameobject.id)
				local rot = go.get_rotation(gameobject.id)
				local scale = go.get_scale(gameobject.id)
				local object = {
					gouid = gouid,
					type = gameobject.type,
					px = pos.x,
					py = pos.y,
					pz = pos.z,
					rx = rot.x,
					ry = rot.y,
					rz = rot.z,
					rw = rot.w,
					sx = scale.x,
					sy = scale.y,
					sz = scale.z,
				}
				table.insert(message.objects, object)
			end
			client.send(b64.encode(json.encode(message)) .. "\n")
			client.update()
		end
	end

	function instance.destroy()
		if client then
			client.destroy()
			client = nil
		end
	end

	function instance.register_gameobject(id, type)
		go_uid_count = go_uid_count + 1
		local gouid = tostring(uid) .. "_" .. go_uid_count
		gameobjects[gouid] = { id = id, type = type, gouid = gouid }
	end

	function instance.unregister_gameobject(id)
		for gouid,gameobject in pairs(gameobjects) do
			if gameobject.id == id then
				gameobjects[gouid] = nil
				local message = {
					action = "GO",
					objects = {
						{
							gouid = gouid,
							deleted = true,
						}
					}
				}
				client.send(b64.encode(json.encode(message)) .. "\n")
				return
			end
		end
	end

	function instance.register_factory(url, type)
		factories[type] = url
	end

	return instance
end


return M
