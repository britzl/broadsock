BROADSOCK_FILES = Broadsock.cpp Message.cpp
GAMELIFT_FILES = GameLiftBroadsock.cpp
OUT = out

init:
	mkdir -p $(OUT)

broadsock: init
	$(CC) $(BROADSOCK_FILES) BroadsockRunner.cpp -o $(OUT)/broadsock -Iinclude -Wall -Werror -O2

gamelift: init
	$(CC) $(BROADSOCK_FILES) $(GAMELIFT_FILES) GameLiftBroadsockRunner.cpp -Iinclude -Llib -laws-cpp-sdk-gamelift-server -lsioclient -lboost_date_time -lboost_random -lboost_system -lprotobuf -lprotoc -lprotobuf-lite -lpthread -lstdc++ -lm -o $(OUT)/gamelift -DGAMELIFT_USE_STD -O2 -std=c++11

clean:
	$(RM) -rf *.o
	$(RM) -rf $(OUT)/broadsock
	$(RM) -rf $(OUT)/gamelift
