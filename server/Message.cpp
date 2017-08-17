#include <Message.h>
#include <stdio.h>
#include <string.h>


Message::Message() {
	index = 0;
	length = 0;
}

int Message::MessageLength() {
	return length;
}
char* Message::MessageContent() {
	return bytes;
}

int Message::ReadInt32() {
	int b0 = bytes[index++];
	int b1 = bytes[index++];
	int b2 = bytes[index++];
	int b3 = bytes[index++];
	return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
}

void Message::ReadString(char* out) {
	int str_length = ReadInt32();
	memcpy(out, &bytes[index], str_length);
	out[str_length] = 0;
	index += str_length;
}

void Message::WriteByte(char byte) {
	bytes[index++] = byte;
	length++;
}

void Message::WriteBytes(char* bytes, int byte_count) {
	memcpy(&this->bytes[index], bytes, byte_count);
	length += byte_count;
}

void Message::WriteInt32(int int32) {
	bytes[index++] = (int32 & 0xFF000000) >> 24;
	bytes[index++] = (int32 & 0x00FF0000) >> 16;
	bytes[index++] = (int32 & 0x0000FF00) >> 8;
	bytes[index++] = int32 & 0x000000FF;
	length += 4;
}

void Message::WriteString(const char* str, int str_length) {
	WriteInt32(str_length);
	memcpy(&bytes[index], str, str_length);
	index += str_length;
	length += str_length;
}

void Message::WriteNullString(const char* str) {
	WriteString(str, strlen(str));
}

void Message::WriteNumber(int number) {
	char buffer[20];
	sprintf(buffer, "%d", number);
	WriteString(buffer, strlen(buffer));
}

void Message::Dump() {
	printf("BEGIN %d\n", length);
	for(int i=0; i < length; i++) {
		printf("  %d = %u (%c)\n", i, bytes[i], bytes[i]);
	}
	printf("END\n\n");
}
