#pragma once

#include <netinet/in.h>
#include <Message.h>


#define MAX_CLIENTS	100
#define PORT 5000

typedef struct {
	struct sockaddr_in addr;
	int connfd;

	/* Unique user id, incremented from Broadsock client count */
	int uid;

	/* Custom user data */
	char customData[250];
} Client;


class Broadsock {
	Client *clients[MAX_CLIENTS];

	/* Current number of connected clients */
	unsigned int clientCount;

	/* uid sequence number to assign to connecting clients. Will increment for every connection */
	int uid;

	/* Master socket fd */
	int masterfd;

	/* Add client to queue */
	void QueueAdd(Client *client);
	/* Delete client from queue */
	void QueueDelete(int uid);

	void Send(int fd, Message message);

protected:
	/** Check if the server is empty, ie has no connected clients */
	bool IsEmpty();
	/* Send message to all clients but the sender */
	void SendMessage(Message message, int uid);
	/* Send message to all clients */
	void SendMessageAll(Message message);
	/* Send message to sender */
	void SendMessageSelf(Message message, int connfd);
	/* Send message to client */
	void SendMessageClient(Message message, int uid);

	/** Handle a disconnected client */
	virtual void HandleClientDisconnected(Client* client);
	/** Handle a connected client */
	bool HandleClientConnected(struct sockaddr_in client_addr, int connfd);
	/** Handle a message from a connected client */
	virtual void HandleClientMessage(Client* client, Message message);

public:
	Broadsock();

	virtual bool Connect();
	bool Start();
};
