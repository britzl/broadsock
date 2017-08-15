/*
 * Based on https://github.com/yorickdewid/Chat-Server
 * And http://www.geeksforgeeks.org/socket-programming-in-cc-handling-multiple-clients-on-server-without-multi-threading/
 */

#include <Broadsock.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>

#define TRUE	1
#define FALSE	0


Broadsock::Broadsock() {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		clients[i] = 0;
	}
	clientCount = 0;
	uid = 10;
}

/* Add client to queue */
void Broadsock::QueueAdd(Client *client) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		if(!clients[i]) {
			clients[i] = client;
			clientCount++;
			return;
		}
	}
}

/* Delete client from queue */
void Broadsock::QueueDelete(int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		if(clients[i]) {
			if(clients[i]->uid == uid) {
				clients[i] = NULL;
				clientCount--;
				return;
			}
		}
	}
}

void Broadsock::Send(int fd, Message message) {
	int length = strlen(message);
	unsigned char b1 = (length & 0xFF000000) >> 24;
	unsigned char b2 = (length & 0x00FF0000) >> 16;
	unsigned char b3 = (length & 0x0000FF00) >> 8;
	unsigned char b4 = length & 0x000000FF;
	send(fd, &b1, 1, 0);
	send(fd, &b2, 1, 0);
	send(fd, &b3, 1, 0);
	send(fd, &b4, 1, 0);
	send(fd, message, strlen(message), 0);
}

/* Send message to all clients but the sender */
void Broadsock::SendMessage(Message message, int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->uid != uid) {
				Send(client->connfd, message);
			}
		}
	}
}

/* Send message to all clients */
void Broadsock::SendMessageAll(Message message) {
	for(int i=0;i<MAX_CLIENTS;i++) {
		Client* client = clients[i];
		if(client) {
			Send(client->connfd, message);
		}
	}
}

/* Send message to sender */
void Broadsock::SendMessageSelf(Message message, int connfd) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->connfd == connfd) {
				Send(client->connfd, message);
				return;
			}
		}
	}
}

/* Send message to client */
void Broadsock::SendMessageClient(Message message, int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->uid == uid) {
				Send(client->connfd, message);
				return;
			}
		}
	}
}

/* Strip CRLF */
void Broadsock::StripNewline(char *s) {
	while(*s != '\0') {
		if(*s == '\r' || *s == '\n') {
			*s = '\0';
		}
		s++;
	}
}

/**
 * Handle a disconnected client
 * This will remove the client from the queue and yield thread
 */
void Broadsock::HandleClientDisconnected(Client* client) {
	// Notify connected clients of the disconnect
	Message message;
	sprintf(message, "{ \"event\": \"DISCONNECT\", \"uid\": %d }", client->uid);
	SendMessage(message, client->uid);

	printf("<<DISCONNECT %s:%d REFERENCED BY %d\n", inet_ntoa(client->addr.sin_addr), ntohs(client->addr.sin_port), client->uid);

	// Close connection
	close(client->connfd);

	// Delete client from queue
	QueueDelete(client->uid);
	free(client);

	//RemovePlayerSession()

	if (clientCount == 0) {
		//TerminateGameSession() ?
		printf("All clients have disconnected\n");
	}
}

/**
 * Handle a connected client
 * This will create a Client struct and fork the thread
 */
bool Broadsock::HandleClientConnected(struct sockaddr_in client_addr, int connfd) {
	Message message;

	// Client settings
	Client *client = (Client *)malloc(sizeof(Client));
	client->addr = client_addr;
	client->connfd = connfd;
	client->uid = uid++;

	printf("<<CONNECT %s:%d REFERENCED BY %d\n", inet_ntoa(client->addr.sin_addr), ntohs(client->addr.sin_port), client->uid);

	// Add client to the queue
	QueueAdd(client);

	// Notify other clients of the new client
	sprintf(message, "{ \"event\": \"CONNECT\", \"uid\": %d, \"ip\": \"%s\", \"port\": %d }", client->uid, inet_ntoa(client_addr.sin_addr), client->addr.sin_port);
	SendMessage(message, client->uid);

	// Notify self of uid
	sprintf(message, "{ \"event\": \"CONNECT\", \"uid\": %d }", client->uid);
	SendMessageSelf(message, client->connfd);
	return true;
}

void Broadsock::HandleClientMessage(Client* client, Message message) {
	Message out;
	sprintf(out, "{ \"event\": \"DATA\", \"uid\": %d, \"data\": \"%s\" }", client->uid, message);
	SendMessage(out, client->uid);
}


bool Broadsock::Connect() {
	// Create master socket
	if((masterfd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
		perror("Socket creation failed");
		return false;
	}

	// Set master socket to allow multiple connections
	int opt = TRUE;
	if(setsockopt(masterfd, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt)) < 0)
	{
		perror("Socket setsockopt failed");
		return false;
	}

	// Socket settings
	struct sockaddr_in serverAddr;
	serverAddr.sin_family = AF_INET;
	serverAddr.sin_addr.s_addr = htonl(INADDR_ANY);
	serverAddr.sin_port = htons(PORT);

	// Bind master socket
	if(bind(masterfd, (struct sockaddr*)&serverAddr, sizeof(serverAddr)) < 0) {
		perror("Socket binding failed");
		return false;
	}

	// Listen on master socket
	if(listen(masterfd, 10) < 0) {
		perror("Socket listening failed");
		return false;
	}

	printf("<[SERVER STARTED]>\n");

	return true;
}

bool Broadsock::Start() {
	// Accept clients
	fd_set readfds;
	while (TRUE) {
		// Clear the socket set
		FD_ZERO(&readfds);

		//add master socket to set
		FD_SET(masterfd, &readfds);

		// Highest file descriptor number, need it for the select function
		int max_sd = masterfd;

		//add child sockets to set
		for(int i = 0; i < MAX_CLIENTS; i++) {
			Client* client = clients[i];
			if(client) {
				FD_SET(client->connfd, &readfds);
				if(client->connfd > max_sd) {
					max_sd = client->connfd;
				}
			}
		}

		// Wait for an activity on one of the sockets, timeout is NULL,
		// so wait indefinitely
		int activity = select(max_sd + 1 , &readfds , NULL , NULL , NULL);
		if((activity < 0) && (errno != EINTR)) {
			printf("select error\n");
		}

		// If something happened on the master socket,
		// then its an incoming connection
		if (FD_ISSET(masterfd, &readfds))
		{
			struct sockaddr_in address;
			socklen_t addrlen = sizeof(address);
			int connfd;
			if ((connfd = accept(masterfd, (struct sockaddr *)&address, (socklen_t*)&addrlen)) < 0) {
				perror("accept");
				exit(EXIT_FAILURE);
			}

			// Check if max clients is reached
			if ((clientCount + 1) == MAX_CLIENTS) {
				printf("<<REJECT %s:%d (MAX CLIENTS REACHED)\n", inet_ntoa(address.sin_addr), ntohs(address.sin_port));
				close(connfd);
			}
			else {
				HandleClientConnected(address, connfd);
			}
		}

		// Check if the clients have any data to read
		for(int i = 0; i < MAX_CLIENTS; i++) {
			Client* client = clients[i];
			if(client) {
				if (FD_ISSET(client->connfd , &readfds)) {
					// Read message length
					unsigned char len[4];
					int ret = read(client->connfd, &len, 4);
					if(ret == 0) {
						HandleClientDisconnected(client);
						continue;
					}
					int length = len[0] << 24 | len[1] << 16 | len[2] << 8 | len[3];

					char ch;
					// Ignore messages that are too long
					if(length > MESSAGE_SIZE) {
						for(int i=0; i<length; i++) {
							int ret;
							if((ret = read(client->connfd, &ch, 1)) == 0) {
								HandleClientDisconnected(client);
								continue;
							}
						}
						continue;
					}

					// Read the message
					Message message;
					for(int i=0; i<length; i++) {
						int ret;
						if((ret = read(client->connfd, &ch, 1)) == 0) {
							HandleClientDisconnected(client);
							continue;
						}
						message[i] = ch;
					}
					message[length] = '\0';

					// Handle message
					HandleClientMessage(client, message);
				}
			}
		}
	}
	return true;
}

int main(int argc, char *argv[]) {
	Broadsock broadsock;
	if (!broadsock.Connect()) {
		exit(EXIT_FAILURE);
	}
	broadsock.Start();
}
