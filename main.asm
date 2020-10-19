.386
.model flat, stdcall
option casemap:none

; 头文件及库
include       windows.inc
include       user32.inc
include       kernel32.inc
include       wsock32.inc
includelib    wsock32.lib
includelib    user32.lib
includelib    kernel32.lib

includelib      msvcrt.lib
printf          PROTO C :ptr sbyte, :VARARG
scanf           PROTO C :ptr sbyte, :VARARG
sscanf          PROTO C :ptr byte,:ptr sbyte,:VARARG

;常量定义
BUF_SIZE = 4096


; sqlite 相关函数原型定义
; 打开数据库
SQLITE_OPEN_PROTO  typedef proto :dword,:dword
SQLITE_OPEN  typedef ptr   SQLITE_OPEN_PROTO

; 关闭数据库
SQLITE_CLOSE_PROTO typedef proto :dword
SQLITE_CLOSE typedef ptr  SQLITE_CLOSE_PROTO

; 执行sql语句
SQLITE_EXEC_CALLBACK_PROTO  typedef proto :dword,:dword,:dword,:dword
SQLITE_EXEC_CALLBACK  typedef ptr  SQLITE_EXEC_CALLBACK_PROTO

; sql 执行回调
SQLITE_EXEC_PROTO  typedef proto :dword,:dword,:SQLITE_EXEC_CALLBACK,:dword,:dword
SQLITE_EXEC  typedef ptr   SQLITE_EXEC_PROTO

; 数据结构定义
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

Client STRUCT
	clientSocket DWORD -1;
	user User<>
Client ENDS

.const
PORT DWORD 5000

; sqlite 相关数据
.data
; 动态链接sqlite库地址
sqlite_lib         DWORD 0
; sqlite db地址
sqlite_db          DWORD 0
sqlite_open       SQLITE_OPEN  ?
sqlite_close      SQLITE_CLOSE ?
sqlite_exec       SQLITE_EXEC ?

; SQLITEite 常量
lib_name BYTE "sqlite3.dll",0
sqlite3_open  BYTE  "sqlite3_open",0
sqlite3_close BYTE  "sqlite3_close",0
sqlite3_exec  BYTE  "sqlite3_exec",0
sqlite3_slct  BYTE  "sqlite3_get_table",0 
file_name      BYTE  "data.sqlite",0  
error_info     DWORD 0

; create table SQLITE
create_user_table_sql  BYTE    "create table if not exists users(id integer primary key autoincrement,",
							"username varchar(30),password varchar(30),avatar varchar(120))",0 
create_message_table_sql BYTE   "create table if not exists messages(idiv integer primary key autoincrement,",
								"time integer,sender_id integer,receiver_id integer,content_type integer,content varchar(200))",0

; insert data SQLITE
insert_user_data_sql    BYTE    "insert into users(username,password,avatar) values(%s,%s,%s)",0
insert_message_data_sql BYTE    "insert into messages(times,sender_id,receiver_id,content_type,content) values(%d,%d,%d,%d,%s)",0

; select data SQLITE
select_user_data_sql    BYTE    "select * from users",0
select_message_data_sql  BYTE   "select * from messages",0


; WSAData init
wsaData WSADATA <>
wVersion WORD 0202h

; listen socket
listen_socket  dword 0

greetMsg BYTE "Starting Server...",0dh,0ah,0

; parse Args
argsFormat BYTE "%s",0

loginArgsFormat BYTE "%s %s %s",0
sendTextArgsFormat BYTE "%s %d %s",0
sendImageArgsFormat BYTE "%s %d %s",0

; command constants
LOGIN_COMMAND BYTE "LOGIN",0
SEND_TEXT_COMMAND BYTE "TEXT",0
SEND_IMAGE_COMMAND BYTE "IMAGE",0

; logs print format
numberFormat BYTE "%d",0dh,0ah,0
loginLogFormat BYTE "User %s %s want to login",0dh,0ah,0

.code
init_db PROC
	push ebp
	mov ebp,esp

	invoke   LoadLibrary,offset lib_name
	mov      sqlite_lib,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_open
	mov		 sqlite_open,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_close
	mov      sqlite_close,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_exec
	mov		 sqlite_exec,eax
	invoke   sqlite_open,offset file_name,offset sqlite_db
	invoke   sqlite_exec,sqlite_db,addr create_user_table_sql,NULL,NULL,offset error_info

	leave
	ret
init_db ENDP

handle_login PROC client_socket:DWORD,@bufAddr:ptr BYTE 
	local commandType[BUF_SIZE]:byte
	local usernameBuf[BUF_SIZE]:byte
	local passwordBuf[BUF_SIZE]:byte

	invoke sscanf,@bufAddr,addr loginArgsFormat,addr commandType,addr usernameBuf,addr passwordBuf
	invoke printf,addr loginLogFormat,addr usernameBuf,addr passwordBuf

	ret
handle_login ENDP

handle_request PROC client_socket:DWORD
	local @buf[BUF_SIZE]:byte
	local commandType[BUF_SIZE]:byte
	
	invoke recv,client_socket,addr @buf,sizeof @buf,0

	invoke printf,addr @buf

	;TODO handle request
	INVOKE sscanf,addr @buf,addr argsFormat,addr commandType;

	; handle LOGIN
	invoke lstrcmp,addr LOGIN_COMMAND,addr commandType
	.if eax ==0
		invoke handle_login,client_socket,addr @buf
	.endif

	; handle send text
	invoke lstrcmp,addr SEND_TEXT_COMMAND,addr commandType
	.if eax==0

	.endif

	; handle send image
	invoke lstrcmp,addr SEND_IMAGE_COMMAND,addr commandType
	.if eax==0

	.endif

	ret
handle_request ENDP

init_server PROC
	local @sock_addr:sockaddr_in

	invoke WSAStartup,wVersion,addr wsaData

	invoke socket,AF_INET,SOCK_STREAM,IPPROTO_TCP
	.if eax == INVALID_SOCKET
		invoke WSAGetLastError
		invoke printf ,addr numberFormat,eax
	.ENDIF


	mov listen_socket,eax
	invoke RtlZeroMemory,addr @sock_addr,sizeof @sock_addr
	invoke htons,PORT
	mov @sock_addr.sin_port,ax
	mov @sock_addr.sin_family,AF_INET
	mov @sock_addr.sin_addr,INADDR_ANY
	invoke bind,listen_socket,addr @sock_addr,sizeof @sock_addr
	
	invoke listen,listen_socket,10
	.while 1
		invoke accept,listen_socket,NULL,0
		.if eax==INVALID_SOCKET
			.break
		.endif
		push ecx
		invoke CreateThread,NULL,0,offset handle_request,eax,NULL,esp
		pop ecx
		invoke CloseHandle,eax
	.endw
	invoke closesocket,listen_socket

	ret
init_server ENDP

main PROC
	invoke init_db
	invoke init_server
	invoke printf,offset greetMsg
main endp
end main
