/*
 * Based on https://github.com/yorickdewid/Chat-Server
 */

#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <pthread.h>
#include <sys/types.h>

#define MAX_CLIENTS	100

#define BUFFER_SIZE 8192

static unsigned int client_count = 0;
static int uid = 10;

/* Client structure */
typedef struct {
	struct sockaddr_in addr;	/* Client remote address */
	int connfd;					/* Connection file descriptor */
	int uid;					/* Client unique identifier */
	char name[32];				/* Client name */
} client_t;

client_t *clients[MAX_CLIENTS];

/* Add client to queue */
void queue_add(client_t *cl) {
	int i;
	for(i=0;i<MAX_CLIENTS;i++) {
		if(!clients[i]) {
			clients[i] = cl;
			client_count++;
			return;
		}
	}
}

/* Delete client from queue */
void queue_delete(int uid) {
	int i;
	for(i=0;i<MAX_CLIENTS;i++) {
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
void send_message(char *s, int uid) {
	int i;
	for(i=0;i<MAX_CLIENTS;i++) {
		if(clients[i]) {
			if(clients[i]->uid != uid) {
				write(clients[i]->connfd, s, strlen(s));
			}
		}
	}
}

/* Send message to all clients */
void send_message_all(char *s) {
	int i;
	for(i=0;i<MAX_CLIENTS;i++) {
		if(clients[i]) {
			write(clients[i]->connfd, s, strlen(s));
		}
	}
}

/* Send message to sender */
void send_message_self(const char *s, int connfd) {
	write(connfd, s, strlen(s));
}

/* Send message to client */
void send_message_client(char *s, int uid) {
	int i;
	for(i=0;i<MAX_CLIENTS;i++) {
		if(clients[i]) {
			if(clients[i]->uid == uid) {
				write(clients[i]->connfd, s, strlen(s));
			}
		}
	}
}

/* Send list of active clients */
void send_active_clients(int connfd) {
	int i;
	char s[64];
	for(i=0;i<MAX_CLIENTS;i++) {
		if(clients[i]) {
			sprintf(s, "<<CLIENT %d | %s\r\n", clients[i]->uid, clients[i]->name);
			send_message_self(s, connfd);
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

/* Print ip address */
void print_client_addr(struct sockaddr_in addr) {
	printf("%d.%d.%d.%d",
		addr.sin_addr.s_addr & 0xFF,
		(addr.sin_addr.s_addr & 0xFF00)>>8,
		(addr.sin_addr.s_addr & 0xFF0000)>>16,
		(addr.sin_addr.s_addr & 0xFF000000)>>24);
}

/**
 * Handle a disconnected client
 * This will remove the client from the queue and yield thread
 */
void handle_client_disconnected(client_t* client) {
	char buff_out[1024];

	// Close connection
	close(client->connfd);

	// Notify connected clients of the disconnect
	sprintf(buff_out, "{ \"event\": \"DISCONNECT\", \"uid\": %d }\r\n", client->uid);
	send_message_all(buff_out);

	// Log disconnect
	printf("<<DISCONNECT ");
	print_client_addr(client->addr);
	printf(" REFERENCED BY %d\n", client->uid);

	// Delete client from queue and yeild thread
	queue_delete(client->uid);
	free(client);
	pthread_detach(pthread_self());

	//RemovePlayerSession()

	if (client_count == 0) {
		//TerminateGameSession() ?
	}
}

/* Handle all communication with the client */
void *handle_client(void *arg) {
	char buff_out[BUFFER_SIZE];
	char buff_in[BUFFER_SIZE];
	//int rlen;

	client_t *client = (client_t *)arg;

	while(1) {
		int length = 0;
		char ch;
		do {
			int ret = read(client->connfd, &ch, 1);
			if (ret < 1) {
				handle_client_disconnected(client);
				return NULL;
			}
			if (ch == '\n') {
				break;
			}
			buff_in[length] = ch;
			length++;
			if (length == BUFFER_SIZE) {
				length = 0;
				break;
			}
		} while(1);

		buff_in[length] = '\0';
		buff_out[0] = '\0';
		strip_newline(buff_in);

		// Ignore empty buffer
		if(!strlen(buff_in)) {
			continue;
		}

		// Send message to the other clients
		//printf("<<DATA %s\n", buff_in);
		sprintf(buff_out, "{ \"event\": \"DATA\", \"uid\": %d, \"data\": \"%s\" }\r\n", client->uid, buff_in);
		send_message(buff_out, client->uid);
	}


	// Receive input from client
	// while((rlen = read(client->connfd, buff_in, sizeof(buff_in) - 1)) > 0) {
	// 	buff_in[rlen] = '\0';
	// 	buff_out[0] = '\0';
	// 	strip_newline(buff_in);
	//
	// 	printf("client thread\r\n ");
	// 	// Ignore empty buffer
	// 	if(!strlen(buff_in)) {
	// 		continue;
	// 	}
	//
	// 	// Send message to the other clients
	// 	//printf("<<DATA %s\n", buff_in);
	// 	sprintf(buff_out, "{ \"event\": \"DATA\", \"uid\": %d, \"data\": \"%s\" }\r\n", client->uid, buff_in);
	// 	send_message(buff_out, client->uid);
	// }

	handle_client_disconnected(client);

	return NULL;
}


/**
 * Handle a connected client
 * This will create a client_t struct and fork the thread
 */
void handle_client_connected(struct sockaddr_in client_addr, int connfd) {
	char buff_out[1024];

	// Client settings
	client_t *client = (client_t *)malloc(sizeof(client_t));
	client->addr = client_addr;
	client->connfd = connfd;
	client->uid = uid++;
	sprintf(client->name, "%d", client->uid);

	printf("<<CONNECT ");
	print_client_addr(client->addr);
	printf(" REFERENCED BY %d\n", client->uid);

	// Add client to the queue and fork thread
	queue_add(client);
	pthread_t tid;
	pthread_create(&tid, NULL, &handle_client, (void*)client);

	// Notify other clients of the new client
	sprintf(buff_out, "{ \"event\": \"CONNECT\", \"uid\": %d, \"ip\": %d, \"port\": %d }\r\n", client->uid, client->addr.sin_addr.s_addr, client->addr.sin_port);
	send_message(buff_out, client->uid);

	// Notify self of uid
	sprintf(buff_out, "{ \"event\": \"CONNECT\", \"uid\": %d }\r\n", client->uid);
	send_message_self(buff_out, client->connfd);


	// AcceptPlayerSession() ?
}


int main(int argc, char *argv[]) {

	//InitSDK()

	// Socket settings
	int listenfd = socket(AF_INET, SOCK_STREAM, 0);

	struct sockaddr_in server_addr;
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = htonl(INADDR_ANY);
	server_addr.sin_port = htons(5000);

	// Bind
	if (bind(listenfd, (struct sockaddr*)&server_addr, sizeof(server_addr)) < 0) {
		perror("Socket binding failed");
		return 1;
	}

	// Listen
	if (listen(listenfd, 10) < 0) {
		perror("Socket listening failed");
		return 1;
	}

	printf("<[SERVER STARTED]>\n");

	//ProcessReady()

	// Accept clients
	while (1) {
		struct sockaddr_in client_addr;
		socklen_t clilen = sizeof(client_addr);
		int connfd = accept(listenfd, (struct sockaddr*)&client_addr, &clilen);

		// Check if max clients is reached
		if ((client_count + 1) == MAX_CLIENTS) {
			printf("<<MAX CLIENTS REACHED\n");
			printf("<<REJECT ");
			print_client_addr(client_addr);
			printf("\n");
			close(connfd);
		}
		else {
			handle_client_connected(client_addr, connfd);
			sleep(1);
		}
	}
}
