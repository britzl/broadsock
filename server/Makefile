broadsock:
	$(CC) BroadsockRunner.cpp Broadsock.cpp -o broadsock -Iinclude -Wall -Werror -O2

gamelift:
	$(CC) GameLiftBroadsockRunner.cpp GameLiftBroadsock.cpp Broadsock.cpp -Iinclude -Llib -static -laws-cpp-sdk-gamelift-server -lsioclient -lboost_date_time -lboost_random -lboost_system -lprotobuf -lpthread -lstdc++ -lm -o gamelift -DGAMELIFT_USE_STD -O2 -std=c++11 

clean:
	$(RM) -rf *.o
	$(RM) -rf broadsock
	$(RM) -rf gamelift
