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
	char* MessageBytes();

	// int ReadInt32();
	// char[] ReadString();

	void WriteInt32(int int32);
	void WriteString(const char* str, int str_length);
	void WriteNullString(const char* str);
	void WriteNumber(int number);
};
