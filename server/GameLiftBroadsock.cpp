#include <GameLiftBroadsock.h>
#include <aws/gamelift/server/GameLiftServerAPI.h>
#include <stdlib.h>
#include <string.h>

#define LOG_PATHS "."


// Implement callback functions
void GameLiftBroadsock::OnStartGameSession(Aws::GameLift::Server::Model::GameSession myGameSession)
{
	printf("[GAMELIFT] OnStartGameSession\n");
	// game-specific tasks when starting a new game session, such as loading map
	Aws::GameLift::Server::ActivateGameSession();

	/// create a game session, in this server it may not be nessecary to do anything specific to create a new game session.
	printf("[GAMELIFT] OnStartGameSession Success\n");
}

void GameLiftBroadsock::OnProcessTerminate()
{
	printf("[GAMELIFT] OnProcessTerminate\n");
	// game-specific tasks required to gracefully shut down a game session,
	// such as notifying players, preserving game state data, and other cleanup
	printf("[GAMELIFT] OnProcessTerminate Success\n");

	TerminateGameSession(0xDEAD);
}

void GameLiftBroadsock::TerminateGameSession(int exitCode)
{
	printf("[GAMELIFT] TerminateGameSession\n");
	///< explicitly release any game sessions

	Aws::GameLift::Server::TerminateGameSession();

	Aws::GameLift::Server::ProcessEnding();

	printf("[GAMELIFT] TerminateGameSession Success\n");

	//::TerminateProcess(::GetCurrentProcess(), exitCode);
	exit(exitCode);
}

bool GameLiftBroadsock::OnHealthCheck()
{
	printf("[GAMELIFT] OnHealthCheck\n");
	bool health = true;
	// complete health evaluation within 60 seconds and set health
	return health;
}

bool GameLiftBroadsock::Connect() {
	if(!Broadsock::Connect()) {
		return false;
	}

	printf("[GAMELIFT] Calling InitSDK\n");
	auto initOutcome = Aws::GameLift::Server::InitSDK();
	if (!initOutcome.IsSuccess()) {
		//return false; - Generally would have this method log and return a false bool, as the main method is an int type I have set to 0.
		perror("[GAMELIFT] InitSDK failed");
		return false;
	}
	printf("[GAMELIFT] InitSDK done\n");

	auto processReadyParameter = Aws::GameLift::Server::ProcessParameters(
		std::bind(&GameLiftBroadsock::OnStartGameSession, this, std::placeholders::_1),
		std::bind(&GameLiftBroadsock::OnProcessTerminate, this),
		std::bind(&GameLiftBroadsock::OnHealthCheck, this),
		PORT,
		Aws::GameLift::Server::LogParameters()
	);

	printf("[GAMELIFT] Calling ProcessReady\n");
	auto readyOutcome = Aws::GameLift::Server::ProcessReady(processReadyParameter);
	if (!readyOutcome.IsSuccess()) {
		perror("[GAMELIFT] ProcessReady failed");
		return false;
	}

	printf("[GAMELIFT] ProcessReady Success (Listen port:%d)\n", PORT);
	return true;
}


void GameLiftBroadsock::HandleClientMessage(Client* client, Message message) {
	message.ReadString(buffer);
	if(strcmp("GL_CLAIM_PLAYER_SESSION", buffer) == 0) {
		message.ReadString(buffer);
		printf("[GAMELIFT] AcceptPlayerSession %s\n", buffer);
		auto outcome = Aws::GameLift::Server::AcceptPlayerSession(buffer);
		if (!outcome.IsSuccess())
		{
			printf("[GAMELIFT] AcceptPlayerSession Fail: %s\n", outcome.GetError().GetErrorMessage().c_str());
			Message playerSessionFailedMessage;
			playerSessionFailedMessage.WriteNumber(client->uid);
			playerSessionFailedMessage.WriteNullString("GL_CLAIM_PLAYER_SESSION_FAILED");
			SendMessageSelf(playerSessionFailedMessage, client->connfd);
		}
		else {
			printf("[GAMELIFT] AcceptPlayerSession Success\n");
			Message playerSessionSuccessMessage;
			playerSessionSuccessMessage.WriteNumber(client->uid);
			playerSessionSuccessMessage.WriteNullString("GL_CLAIM_PLAYER_SESSION_SUCCESS");
			SendMessageSelf(playerSessionSuccessMessage, client->connfd);
		}
	}
	else {
		message.Rewind();
		Broadsock::HandleClientMessage(client, message);
	}
}
