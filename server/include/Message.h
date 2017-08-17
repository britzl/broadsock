#pragma once

#define MESSAGE_SIZE 8192

class Message {
	char bytes[MESSAGE_SIZE];
	int index;
	int length;

public:
	Message();

	int MessageLength();
	char* MessageContent();

	void Rewind();

	int ReadInt32();
	void ReadString(char* out);

	void WriteByte(char byte);
	void WriteBytes(char* bytes, int byte_count);
	void WriteInt32(int int32);

	void WriteString(const char* str, int str_length);
	void WriteNullString(const char* str);
	void WriteNumber(int number);

	void Dump();
};
