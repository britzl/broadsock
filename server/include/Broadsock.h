#pragma once

#include <netinet/in.h>


#define MAX_CLIENTS	5
#define MESSAGE_SIZE 8192

#define PORT 5000


typedef char Message[MESSAGE_SIZE];

typedef struct {
	struct sockaddr_in addr;
	int connfd;
	int uid;
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
	/* Send message to all clients but the sender */
	void SendMessage(Message message, int uid);
	/* Send message to all clients */
	void SendMessageAll(Message message);
	/* Send message to sender */
	void SendMessageSelf(Message message, int connfd);
	/* Send message to client */
	void SendMessageClient(Message message, int uid);
	/* Strip CRLF */
	void StripNewline(char *s);
	/**
	 * Handle a disconnected client
	 * This will remove the client from the queue and yield thread
	 */
	void HandleClientDisconnected(Client* client);
	/**
	 * Handle a connected client
	 * This will create a Client struct and fork the thread
	 */
	bool HandleClientConnected(struct sockaddr_in client_addr, int connfd);
	/**
	 * Handle a message from a connected client
	 */
	void HandleClientMessage(Client* client, Message message);

public:
	Broadsock();

	bool Connect();
	bool Start();
};