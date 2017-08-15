CFLAGS = -O2 -lpthread
CPPFLAGS = -std=c++11 -lstdc++
INCL = -Iinclude

broadsock:
	$(CC) -Wall -Werror $(CFLAGS) $(INCL) BroadsockRunner.cpp Broadsock.cpp -o broadsock

gamelift:
	$(CC)  $(CFLAGS) $(CPPFLAGS) $(INCL) GameLiftBroadsockRunner.cpp GameLiftBroadsock.cpp Broadsock.cpp -Llib -static -laws-cpp-sdk-gamelift-server -lsioclient -lboost_date_time -lboost_random -lboost_system -lprotobuf -o gamelift -DGAMELIFT_USE_STD

clean:
	$(RM) -rf *.o
	$(RM) -rf broadsock
	$(RM) -rf gamelift
