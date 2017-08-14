CFLAGS = -O2 -lpthread
CPPFLAGS = -std=c++11

broadsock:
	$(CC) -Wall -Werror Broadsock.cpp $(CFLAGS) -o broadsock -Iinclude

gamelift:
	$(CC) GameLiftBroadsock.cpp lib/aws-cpp-sdk-gamelift-server.lib $(CFLAGS) $(CPPFLAGS) -o gamelift -Iinclude  -DGAMELIFT_USE_STD

clean:
	$(RM) -rf broadsock
	$(RM) -rf gamelift
