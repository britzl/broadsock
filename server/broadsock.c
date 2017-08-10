/*
 * Based on https://github.com/yorickdewid/Chat-Server
 * And http://www.geeksforgeeks.org/socket-programming-in-cc-handling-multiple-clients-on-server-without-multi-threading/
 */

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <aws/gamelift/server/GameLiftServerAPI.h>

#define TRUE	1
#define FALSE	0

#define PORT 5000
#define MAX_CLIENTS	5

#define MESSAGE_SIZE 8192

static unsigned int client_count = 0;
static int uid = 10;

typedef char Message[MESSAGE_SIZE];

typedef struct {
	struct sockaddr_in addr;
	int connfd;
	int uid;
} Client;

Client *clients[MAX_CLIENTS];

/* Add client to queue */
void queue_add(Client *client) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		if(!clients[i]) {
			clients[i] = client;
			client_count++;
			return;
		}
	}
}

/* Delete client from queue */
void queue_delete(int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		if(clients[i]) {
			if(clients[i]->uid == uid) {
				clients[i] = NULL;
				client_count--;
				return;
			}
		}
	}
}

/* Send message to all clients but the sender */
void send_message(Message message, int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->uid != uid) {
				send(client->connfd, message, strlen(message), 0);
			}
		}
	}
}

/* Send message to all clients */
void send_message_all(Message message) {
	for(int i=0;i<MAX_CLIENTS;i++) {
		Client* client = clients[i];
		if(client) {
			send(client->connfd, message, strlen(message), 0);
		}
	}
}

/* Send message to sender */
void send_message_self(Message message, int connfd) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->connfd == connfd) {
				send(client->connfd, message, strlen(message), 0);
				return;
			}
		}
	}
}

/* Send message to client */
void send_message_client(Message message, int uid) {
	for(int i = 0; i < MAX_CLIENTS; i++) {
		Client* client = clients[i];
		if(client) {
			if(client->uid == uid) {
				send(client->connfd, message, strlen(message), 0);
				return;
			}
		}
	}
}

/* Strip CRLF */
void strip_newline(char *s) {
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
void handle_client_disconnected(Client* client) {
	// Notify connected clients of the disconnect
	Message message;
	sprintf(message, "{ \"event\": \"DISCONNECT\", \"uid\": %d }\r\n", client->uid);
	send_message(message, client->uid);

	printf("<<DISCONNECT %s:%d REFERENCED BY %d\n", inet_ntoa(client->addr.sin_addr), ntohs(client->addr.sin_port), client->uid);

	// Close connection
	close(client->connfd);

	// Delete client from queue
	queue_delete(client->uid);
	free(client);

	//RemovePlayerSession()

	if (client_count == 0) {
		//TerminateGameSession() ?
		printf("All clients have disconnected\n");
	}
}

/**
 * Handle a connected client
 * This will create a Client struct and fork the thread
 */
void handle_client_connected(struct sockaddr_in client_addr, int connfd) {
	Message message;

	// Client settings
	Client *client = (Client *)malloc(sizeof(Client));
	client->addr = client_addr;
	client->connfd = connfd;
	client->uid = uid++;

	printf("<<CONNECT %s:%d REFERENCED BY %d\n", inet_ntoa(client->addr.sin_addr), ntohs(client->addr.sin_port), client->uid);

	// Add client to the queue
	queue_add(client);

	// Notify other clients of the new client
	sprintf(message, "{ \"event\": \"CONNECT\", \"uid\": %d, \"ip\": \"%s\", \"port\": %d }\r\n", client->uid, inet_ntoa(client_addr.sin_addr), client->addr.sin_port);
	send_message(message, client->uid);

	// Notify self of uid
	sprintf(message, "{ \"event\": \"CONNECT\", \"uid\": %d }\r\n", client->uid);
	send_message_self(message, client->connfd);

	//The player session ID that GameLift has passed back to the player needs to be passed into this method and used in the API call below, I have left the parameter called playerSessionId to illustrate this.
	//This is something that the client will need to pass to the server.
	auto outcome = Aws::GameLift::Server::AcceptPlayerSession(playerSessionId);

	if (outcome.IsSuccess())
	{
		return true;
	}

	printf("[GAMELIFT] AcceptPlayerSession Fail: %s\n", outcome.GetError().GetErrorMessage().c_str());
	return false;
}


int main(int argc, char *argv[]) {

	auto initOutcome = Aws::GameLift::Server::InitSDK();

	if (!initOutcome.IsSuccess())
		//return false; - Generally would have this method log and return a false bool, as the main method is an int type I have set to 0.
		perror("GameLift InitSDK failed");
		return 0;

	// Create master socket
	int masterfd;
	if((masterfd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
		perror("Socket creation failed");
		exit(EXIT_FAILURE);
	}

	// Set master socket to allow multiple connections
	int opt = TRUE;
	if(setsockopt(masterfd, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt)) < 0)
	{
		perror("Socket setsockopt failed");
		exit(EXIT_FAILURE);
	}

	// Socket settings
	struct sockaddr_in server_addr;
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	server_addr.sin_port = htons(PORT);

	// Bind master socket
	if(bind(masterfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
		perror("Socket binding failed");
		exit(EXIT_FAILURE);
	}

	// Listen on master socket
	if(listen(masterfd, 10) < 0) {
		perror("Socket listening failed");
		exit(EXIT_FAILURE);
	}

	printf("<[SERVER STARTED]>\n");

	auto processReadyParameter = Aws::GameLift::Server::ProcessParameters(
		std::bind(&GameLiftManager::OnStartGameSession, this, std::placeholders::_1),
		std::bind(&GameLiftManager::OnProcessTerminate, this),
		std::bind(&GameLiftManager::OnHealthCheck, this),
		PORT, Aws::GameLift::Server::LogParameters(logPaths)
	);

	auto readyOutcome = Aws::GameLift::Server::ProcessReady(processReadyParameter);
	if (!readyOutcome.IsSuccess()) {
		perror("GameLift ProcessReady failed");
		return false;
	}

	printf("GAMELIFT] ProcessReady Success (Listen port:%d)\n", PORT);

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
			printf("select error");
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
			if ((client_count + 1) == MAX_CLIENTS) {
				printf("<<REJECT %s:%d (MAX CLIENTS REACHED)\n", inet_ntoa(address.sin_addr), ntohs(address.sin_port));
				close(connfd);
			}
			else {
				handle_client_connected(address, connfd);
			}
		}

		// Check if the clients have any data to read
		for(int i = 0; i < MAX_CLIENTS; i++) {
			Client* client = clients[i];
			if(client) {
				if (FD_ISSET(client->connfd , &readfds)) {
					// Read a single message, one byte at a time until linebreak
					Message message;
					int length = 0;
					char ch;
					do {
						int ret;
						if((ret = read(client->connfd, &ch, 1)) == 0) {
							handle_client_disconnected(client);
							length = 0;
							break;
						}
						if (ch == '\n') {
							break;
						}
						message[length] = ch;
						length++;
						if (length == MESSAGE_SIZE) {
							length = 0;
							break;
						}
					} while(TRUE);

					// Handle message
					if(length > 0) {
						// Null terminate message and send to other clients
						message[length] = '\0';
						Message out;
						sprintf(out, "{ \"event\": \"DATA\", \"uid\": %d, \"data\": \"%s\" }\r\n", client->uid, message);
						send_message(out, client->uid);
					}
				}
			}
		}
	}
}

// Implement callback functions
void broadsock::onStartGameSession(Aws::GameLift::Model::GameSession myGameSession)
{
   // game-specific tasks when starting a new game session, such as loading map
   	Aws::GameLift::Server::ActivateGameSession();

	/// create a game session, in this server it may not be nessecary to do anything specific to create a new game session.

	printf("[GAMELIFT] OnStartGameSession Success\n");
}

void broadsock::onProcessTerminate()
{
   // game-specific tasks required to gracefully shut down a game session,
   // such as notifying players, preserving game state data, and other cleanup
	printf("[GAMELIFT] OnProcessTerminate Success\n");

	TerminateGameSession(0xDEAD);
}

void broadsock::TerminateGameSession(int exitCode)
{
	///< explicitly release ay game sessions

	Aws::GameLift::Server::TerminateGameSession();

	Aws::GameLift::Server::ProcessEnding();

	::TerminateProcess(::GetCurrentProcess(), exitCode);
}

bool broadsock::onHealthCheck()
{
    bool health;
    // complete health evaluation within 60 seconds and set health
    return health;
}
