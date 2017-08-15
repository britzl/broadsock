CFLAGS = -O2 -lpthreads
CPPFLAGS = -std=c++11 -lstdc++

broadsock:
	$(CC) -g -Wall -Werror Broadsock.cpp $(CFLAGS) -o broadsock -Iinclude

gamelift:
	$(CC) GameLiftBroadsock.cpp -Llib -laws-cpp-sdk-gamelift-server $(CFLAGS) $(CPPFLAGS) -o gamelift -Iinclude  -DGAMELIFT_USE_STD

clean:
	$(RM) -rf broadsock
	$(RM) -rf gamelift
