#include <Broadsock.h>
#include <stdlib.h>
#include <stdio.h>


int main(int argc, char *argv[]) {
	Broadsock broadsock;
	if (!broadsock.Connect()) {
		exit(EXIT_FAILURE);
	}
	broadsock.Start();
}
