CFLAGS = -O2 -lpthread
CPPFLAGS = -std=c++11 -lstdc++

broadsock:
	$(CC) -Wall -Werror Broadsock.cpp $(CFLAGS) -o broadsock -Iinclude

gamelift:
	$(CC) -Wall -Werror $(CFLAGS) -Iinclude -c Broadsock.cpp
	$(CC) GameLiftBroadsock.cpp Broadsock.o -Llib -static -laws-cpp-sdk-gamelift-server -lsioclient -lboost_date_time -lboost_random -lboost_system $(CFLAGS) $(CPPFLAGS) -o gamelift -Iinclude  -DGAMELIFT_USE_STD

clean:
	$(RM) -rf broadsock
	$(RM) -rf gamelift
