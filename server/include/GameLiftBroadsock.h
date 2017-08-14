#pragma once

#include <Broadsock.h>
#include <aws/gamelift/server/GameLiftServerAPI.h>

class GameLiftBroadsock : public Broadsock {
	// GameLift callback functions
	void OnProcessTerminate();
	void OnStartGameSession(Aws::GameLift::Server::Model::GameSession myGameSession);
	void TerminateGameSession(int exitCode);
	bool OnHealthCheck();

public:
	bool Connect();
};
