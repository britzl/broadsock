#include <GameLiftBroadsock.h>
#include <aws/gamelift/server/GameLiftServerAPI.h>
#include <stdlib.h>

#define LOG_PATHS "."


// Implement callback functions
void GameLiftBroadsock::OnStartGameSession(Aws::GameLift::Server::Model::GameSession myGameSession)
{
	// game-specific tasks when starting a new game session, such as loading map
	Aws::GameLift::Server::ActivateGameSession();

	/// create a game session, in this server it may not be nessecary to do anything specific to create a new game session.
	printf("[GAMELIFT] OnStartGameSession Success\n");
}

void GameLiftBroadsock::OnProcessTerminate()
{
	// game-specific tasks required to gracefully shut down a game session,
	// such as notifying players, preserving game state data, and other cleanup
	printf("[GAMELIFT] OnProcessTerminate Success\n");

	TerminateGameSession(0xDEAD);
}

void GameLiftBroadsock::TerminateGameSession(int exitCode)
{
	///< explicitly release any game sessions

	Aws::GameLift::Server::TerminateGameSession();

	Aws::GameLift::Server::ProcessEnding();

	//::TerminateProcess(::GetCurrentProcess(), exitCode);
	exit(exitCode);
}

bool GameLiftBroadsock::OnHealthCheck()
{
	bool health = true;
	// complete health evaluation within 60 seconds and set health
	return health;
}

bool GameLiftBroadsock::Connect() {
	if(!Broadsock::Connect()) {
		return false;
	}

	auto initOutcome = Aws::GameLift::Server::InitSDK();
	if (!initOutcome.IsSuccess()) {
		//return false; - Generally would have this method log and return a false bool, as the main method is an int type I have set to 0.
		perror("GameLift InitSDK failed");
		return false;
	}

	auto processReadyParameter = Aws::GameLift::Server::ProcessParameters(
		std::bind(&GameLiftBroadsock::OnStartGameSession, this, std::placeholders::_1),
		std::bind(&GameLiftBroadsock::OnProcessTerminate, this),
		std::bind(&GameLiftBroadsock::OnHealthCheck, this),
		PORT,
		Aws::GameLift::Server::LogParameters()
	);

	auto readyOutcome = Aws::GameLift::Server::ProcessReady(processReadyParameter);
	if (!readyOutcome.IsSuccess()) {
		perror("GameLift ProcessReady failed");
		return false;
	}

	printf("GAMELIFT] ProcessReady Success (Listen port:%d)\n", PORT);
	return true;
}

/*

	//The player session ID that GameLift has passed back to the player needs to be passed into this method and used in the API call below, I have left the parameter called playerSessionId to illustrate this.
	//This is something that the client will need to pass to the server.
	auto outcome = Aws::GameLift::Server::AcceptPlayerSession(playerSessionId);
	if (!outcome.IsSuccess())
	{
		printf("[GAMELIFT] AcceptPlayerSession Fail: %s\n", outcome.GetError().GetErrorMessage().c_str());
		return false;
	}

*/
