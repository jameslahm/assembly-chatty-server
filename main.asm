.386
.model flat, stdcall
option casemap:none

include sqlite3.inc

includelib      msvcrt.lib
printf          PROTO C :ptr sbyte, :VARARG
scanf           PROTO C :ptr sbyte, :VARARG

User STRUCT
	id	DWORD 0; 用户id
	username BYTE 30 dup(0);用户名 最长30个字节
	password BYTE 30 dup(0);用户密码 最长30个字节
	avatar BYTE 120 dup(0);用户头像链接 最长120个字节
User ENDS

Message STRUCT
	id DWORD 0; 消息id
	time DWORD 0; 消息时间
	sender_id DWORD 0; 发送者id
	receiver_id DWORD 0; 接收者id
	content_type DWORD 0; 消息类型：文本-0 图片-1
	content BYTE 200 dup(0); 消息内容
Message ENDS

.data
greetMsg BYTE "Hello world!",0dh,0ah,0

.code

main PROC
	invoke printf,offset greetMsg
main ENDP
end main
