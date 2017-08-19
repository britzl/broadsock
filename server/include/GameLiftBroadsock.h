#pragma once

#include <Broadsock.h>
#include <Message.h>
#include <aws/gamelift/server/GameLiftServerAPI.h>

class GameLiftBroadsock : public Broadsock {
	// buffer for peeking at the client message
	char buffer[MESSAGE_SIZE];

	// GameLift callback functions
	void OnProcessTerminate();
	void OnStartGameSession(Aws::GameLift::Server::Model::GameSession myGameSession);
	void TerminateGameSession(int exitCode);
	bool OnHealthCheck();

protected:
	void HandleClientMessage(Client* client, Message message);
	void HandleClientDisconnected(Client *client);

public:
	bool Connect();
};
