#pragma once

#include <Broadsock.h>


class GameLiftBroadsock : public Broadsock {
	// GameLift callback functions
	void OnStartGameSession(Aws::GameLift::Server::Model::GameSession myGameSession);
	void OnProcessTerminate();
	void TerminateGameSession(int exitCode);
	bool OnHealthCheck();

public:
	bool Connect();
};
