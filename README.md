# Broadsock
Broadsock is a TCP socket broadcast server and client for the Defold game engine. The primary purpose of the server is to synchronize the positions of game objects in a Defold game and create and delete game object instances as they are created and deleted on remote clients. The Broadsock server will listen for client connections, maintain a list of currently connected clients and broadcast any received data to all connected clients but the sender.

The Broadsock server and client communicates using a message format that handles raw bytes, strings and integers.

## Message format
A Broadsock message has the following format:

````
+------------+-~~~~~~~~~~~~-+-~~~~~~~~~~~~~~~-+-~~~~~~~~-+
| LENGTH [4] | UID [string] | MSG_ID [string] | DATA [*] |
+------------+-~~~~~~~~~~~~-+-~~~~~~~~~~~~~~~-+-~~~~~~~~-+
````

* LENGTH = Length of the message in bytes
* UID = Unique ID of the player that sent the message (only when broadcast from server)
* MSG_ID = Message id
* DATA = Message data

### Message ids
Broadsock has a number of reserved message ids:

* CONNECT_OTHER - Sent to other connected clients when a new client connects. Contains the unique user id of the connected client, as well as IP and port.
* CONNET_SELF - Sent from the server to the connecting client. Contains a unique user id for the connected client.
* DISCONNECT - Broadcast from the server when a client disconnects
* GO - Sent from a client every update. Contains a list of transform updates for registered game objects. Will be broadcast to the other clients.
* GOD - Sent from a client when a game object is unregistered. Will be broadcast to the other clients.

## Installation
You can use the Broadsock client in your own project by adding this project as a [Defold library dependency](http://www.defold.com/manuals/libraries/). Open your game.project file and in the dependencies field under project add:

	https://github.com/britzl/broadsock/archive/master.zip

Or point to the ZIP file of a [specific release](https://github.com/britzl/broadsock/releases).

## Usage
The easiest way to get started with Broadsock is to add the ````broadsock/broadsock.go```` instance to a collection in your game and then use message passing to connect and register game objects:

	local BROADSOCK = msg.url("example:/broadsock#script")

	function init(self)
		-- Tell broadsock to connect to a Broadsock server instance
		msg.post(BROADSOCK, "connect", { ip = "127.0.0.1", port = 5000 })
	end

	function on_message(self, message_id, message, sender)
		if message_id == hash("connected") and sender == BROADSOCK then
			-- Register a bullet factory
			msg.post(BROADSOCK, "register_factory", { url = "/factory#bullet", type = "bullet" })
		end
	end

	function on_input(self, action_id, action)
		if action_id == hash("fire") and action.released then
			-- Register a bullet game object
			-- This game object will automatically sync it's position with other broadsock connected clients
			-- The receiving clients will automatically create game objects on their end
			self.bullet_id = factory.create("/factory#bullet")
			msg.post(BROADSOCK, "register_gameobject", { id = self.bullet_id, type = "bullet" })
		end
	end

	function update(self, dt)
		... move bullet

		-- Unregister a game object
		-- This game object will no longer sync it's position with other broadsock connected clients
		-- The fact that the game object was unregistered will be sent to the other clients and their
		-- remote counter parts will automatically be deleted
		go.delete(self.bullet_id)
		msg.post(BROADSOCK, "unregister_gameobject", { id = self.bullet_id })
	end
