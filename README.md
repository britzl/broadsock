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

LENGTH = Length of the message in bytes
UID = Unique ID of the player that sent the message (only when broadcast from server)
MSG_ID = Message id
DATA = Message data

### Message ids
Broadsock has a number of reserved message ids:

* CONNECT_OTHER - Sent to other connected clients when a new client connects. Contains the unique user id of the connected client, as well as IP and port.
* CONNET_SELF - Sent from the server to the connecting client. Contains a unique user id for the connected client.
* DISCONNECT - Broadcast from the server when a client disconnects
* GO - Sent from a client every update. Contains a list of transform updates for registered game objects. Will be broadcast to the other clients.
* GOD - Sent from a client when a game object is unregistered. Will be broadcast to the other clients.
