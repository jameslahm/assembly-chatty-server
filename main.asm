.386
.model flat, stdcall
option casemap:none

; 头文件及库
;include ws2_32.inc
;includelib ws2_32.lib
;include masm32.inc
;includelib masm32.lib
;include wsock32.inc
;include msvcrt.inc
include       windows.inc
include       user32.inc
include       kernel32.inc
include       wsock32.inc
includelib    wsock32.lib
includelib    user32.lib
includelib    kernel32.lib
include       comdlg32.inc
includelib    comdlg32.lib

include msvcrt.inc
includelib      msvcrt.lib
printf          PROTO C :ptr sbyte, :VARARG
scanf           PROTO C :ptr sbyte, :VARARG
sscanf          PROTO C :ptr byte,:ptr sbyte,:VARARG
sprintf         PROTO C :ptr byte,:ptr sbyte,:VARARG
srand           PROTO C :dword
rand            PROTO C
time	        PROTO C :ptr dword
fopen			PROTO C :DWORD, :DWORD
fprintf         PROTO C :DWORD,:DWORD,:VARARG
fflush          PROTO C :DWORD
fscanf          PROTO C :DWORD,:DWORD,:VARARG
fclose          PROTO C :DWORD

;常量定义
BUF_SIZE = 4096


; 数据结构定义
User STRUCT
	password BYTE 30 dup(0);用户密码 最长30个字节
	username BYTE 30 dup(0);用户名 最长30个字节
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

.data
; 数据库文件 users.db messages.db
userDBName BYTE "users.db",0
messageDBName BYTE "messages.db",0
friendDBName BYTE "friends.db",0
userDBMode BYTE "a+",0
messageDBMode BYTE "a+",0
friendDBMode BYTE "a+",0
hUserDB DWORD ?
hMessageDB DWORD ?
hFriendDB DWORD ?

userDataFormat BYTE "%s %s",0dh,0ah,0
friendDataFormat BYTE "%s %s",0dh,0ah,0

; WSAData init
wsaData WSADATA <>
wVersion WORD 0202h

; listen socket
listenSocket  dword 0

greetMsg BYTE "Starting Server...",0dh,0ah,0

; parse Args
argsFormat BYTE "%s",0

loginArgsFormat BYTE "%s %s %s",0
registerArgsFormat BYTE "%s %s %s",0
sendTextArgsFormat BYTE "%s %s %s",0
sendImageArgsFormat BYTE "%s %s %d",0

; command constants
REGISTER_COMMAND BYTE "REGISTER",0
LOGIN_COMMAND BYTE "LOGIN",0
SEND_TEXT_COMMAND BYTE "TEXT",0
SEND_IMAGE_COMMAND BYTE "IMAGE",0
GET_FRIENDS_COMMAND BYTE "FRIENDS",0
GET_MESSAGES_COMMAND BYTE "MESSAGES",0

; logs print format
debugFormat BYTE "DEBUG!!",0dh,0ah,0
debugStrFormat BYTE "DEBUG %s",0dh,0ah,0
debugNumFormat BYTE "DEBUG %d",0dh,0ah,0
registerLogFormat BYTE "User %s(password:%s) register",0dh,0ah,0
loginLogFormat BYTE "User %s(password:%s) login",0dh,0ah,0
sendTextLogFormat BYTE "User %s send %s(text) to %s",0dh,0ah,0
sendImageLogFormat BYTE "User %s send %s(image:%d) to %s",0dh,0ah,0

; response message
successResponse BYTE "SUCCESS",0dh,0ah,0
successResponseLen DWORD 9
failureResponse BYTE "ERROR",0dh,0ah,0
failureResponseLen DWORD 9

textResponseFormat BYTE "TEXT %s",0dh,0ah,0
imageResponseFormat BYTE "IMAGE %s",0dh,0ah,0

; all clients
clients Client 50 dup(<>)
fakeId DWORD 1

; heap handle
hHeap DWORD ?

GetClient MACRO client:=<client>
	mov eax,client
	assume eax:ptr Client
ENDM

GetDB MACRO 
	INVOKE fopen,addr userDBName,addr userDBMode
	mov hUserDB,eax
	INVOKE fopen,addr messageDBName,addr messageDBMode
	mov hMessageDB,eax
	INVOKE fopen,addr friendDBName,addr friendDBMode
	mov hFriendDB,eax
ENDM

CloseDB MACRO
	invoke fflush,hUserDB
	invoke fclose,hUserDB
	invoke fflush,hFriendDB
	invoke fclose,hFriendDB
	invoke fflush,hMessageDB
	invoke fclose,hMessageDB
ENDM

BZero MACRO buf:=<buf>,bufSize:=<BUF_SIZE>
	INVOKE RtlZeroMemory,addr buf,bufSize
ENDM


.code


getClientByUserName PROC receiverNameAddr:DWORD
	mov eax,offset clients
	assume eax:ptr Client
	.WHILE TRUE
		lea ebx,[eax].user.username
		push eax
		invoke lstrcmp,ebx,receiverNameAddr
		mov ecx,eax
		pop eax
		.if ecx==0
			assume eax:nothing
			.BREAK
		.else
			add eax,sizeof Client
		.endif
	.ENDW
	ret
getClientByUserName ENDP

verifyUser PROC usernameAddr:ptr BYTE,passwordAddr:ptr BYTE
	local username[BUF_SIZE]:BYTE
	local password[BUF_SIZE]:BYTE
	
	BZero username
	BZero password

	GetDB
	.WHILE TRUE
		invoke fscanf,hUserDB,addr userDataFormat,addr username,addr password
		.if eax <=0
			mov eax,-1
			.break
		.endif
		invoke lstrcmp,addr username,usernameAddr
		.if eax == 0
			invoke lstrcmp,addr password,passwordAddr
			.if eax== 0
				mov eax,0
				.break
			.ENDIF
		.endif
	.ENDW
	CloseDB
	ret
verifyUser ENDP


handle_login PROC client:ptr Client,@bufAddr:ptr BYTE 
	local commandType[BUF_SIZE]:byte
	local isVerified:dword

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sscanf,@bufAddr,addr loginArgsFormat,addr commandType,ebx,ecx
	
	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke verifyUser,ebx,ecx
	mov isVerified,eax

	invoke printf,addr debugFormat

	.if isVerified == 0
		GetClient
		lea ebx,[eax].user.username
		lea ecx,[eax].user.password
		invoke printf,addr loginLogFormat,ebx,ecx

		GetClient
		invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0
	.else
		GetClient
		invoke send,[eax].clientSocket,addr failureResponse,failureResponseLen,0
	.endif

	assume eax:nothing
	ret
handle_login ENDP

insert_user PROC usernameAddr:ptr BYTE,passwordAddr:ptr BYTE
	GetDB
	invoke fprintf,hUserDB,addr userDataFormat,usernameAddr,passwordAddr
	CloseDB
	ret
insert_user ENDP

handle_register PROC client:ptr Client,@bufAddr:ptr BYTE 
	local commandType[BUF_SIZE]:byte

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sscanf,@bufAddr,addr registerArgsFormat,addr commandType,ebx,ecx

	; insert user to database
	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	INVOKE insert_user,ebx,ecx


	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke printf,addr registerLogFormat,ebx,ecx

	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	assume eax:nothing
	ret
handle_register ENDP

get_friends PROC usernameAddr:ptr BYTE
	local user1Name[BUF_SIZE]:BYTE
	local user2Name[BUF_SIZE]:BYTE
	local buf[BUF_SIZE]:BYTE
	
	GetDB
	.WHILE TRUE
		invoke fscanf,hFriendDB,addr friendDataFormat,addr user1Name,addr user2Name
		.if eax <=0
			mov eax,-1
			.break
		.endif
		invoke lstrcmp,addr username,usernameAddr
		.if eax == 0
			invoke lstrcmp,addr password,passwordAddr
			.if eax== 0
				mov eax,0
				.break
			.ENDIF
		.endif
	.ENDW
	CloseDB

get_friends ENDP

handle_get_friends PROC client:ptr Client,@bufAddr:ptr BYTE 
	GetClient
	lea ebx,[eax].user.username
	INVOKE get_friends,ebx

	ret
handle_get_friends ENDP

handle_get_messages PROC client:ptr Client,@bufAddr:ptr BYTE 
	ret
handle_get_messages ENDP

handle_send_message PROC USES eax client:ptr Client,@bufAddr:ptr BYTE
	local commandType[BUF_SIZE]:byte
	local receiverName:DWORD
	local message[BUF_SIZE]:byte
	local receiver:ptr Clinet
	local receiverBuf[BUF_SIZE]:byte

	invoke sscanf,@bufAddr,addr sendTextArgsFormat,addr commandType,addr receiverName,addr message

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke printf,addr sendTextLogFormat,ebx,addr message,addr receiverName


	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	invoke getClientByUserName,addr receiverName
	mov receiver,eax

	invoke sprintf,addr receiverBuf,addr textResponseFormat,addr message

	invoke lstrlen,addr receiverBuf
	mov ecx,eax

	GetClient receiver
	mov ebx,[eax].clientSocket
	invoke send,ebx,addr receiverBuf,ecx,0
	

	assume eax:nothing

	ret
handle_send_message ENDP

; 随机生成10位图片文件名
generateRandomImageName PROC buf:ptr BYTE
	local count:sdword
	mov count,10

	invoke time,NULL
	invoke srand,eax
		
	.while count>=1
		invoke rand
		mov edx,0
		mov ecx,26
		div ecx
		mov eax,edx
		add eax,61h
		
		mov ecx,buf

		mov edx,count
		mov ebx,10
		sub ebx,edx
		mov [ecx+ebx],al

		dec count
	.endw
	ret
generateRandomImageName ENDP

handle_send_image PROC USES eax client:ptr Client,@bufAddr:ptr BYTE
	local commandType[BUF_SIZE]:byte
	local receiverName:DWORD
	local imageSize:DWORD
	local imageName[BUF_SIZE]:byte
	local imageBuf[BUF_SIZE]:byte
	local hasReceivedSize:dword
	local fileHandle:dword
	local bytesWrite:dword
	

	invoke sscanf,@bufAddr,addr sendImageArgsFormat,addr commandType,addr receiverName,addr imageSize

	invoke generateRandomImageName, addr imageName

	invoke printf,addr debugStrFormat,addr imageName

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke printf,addr sendImageLogFormat,ebx,addr imageName,imageSize,addr receiverName

	;create image file
	invoke CreateFile,addr imageName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
	mov fileHandle,eax

	; start recv image content
	mov hasReceivedSize,0
	mov eax,imageSize

	.WHILE hasReceivedSize <= eax
		GetClient
		mov ebx,[eax].clientSocket
		invoke recv,ebx,addr imageBuf,BUF_SIZE - 1,0

		.if eax ==0 
			invoke CloseHandle,fileHandle
			.BREAK
		.endif

		add hasReceivedSize,eax
		mov ebx,eax
		invoke WriteFile,fileHandle,addr imageBuf,ebx,addr bytesWrite,NULL

	.endw


	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	assume eax:nothing

	ret

handle_send_image ENDP

init_client PROC clientSocket:DWORD
	mov eax,offset clients
	assume eax:ptr Client
	.WHILE TRUE
		.if [eax].clientSocket == -1
			push clientSocket
			pop [eax].clientSocket
			assume eax:nothing
			.BREAK
		.else
			add eax,sizeof Client
		.endif
	.ENDW
	ret
init_client ENDP

handle_request PROC clientSocket:DWORD
	local @buf[BUF_SIZE]:byte
	local commandType[BUF_SIZE]:byte
	local client:ptr Client
	
	invoke init_client,clientSocket
	mov client,eax
	
	;invoke RtlZeroMemory,addr client,sizeof client

	.WHILE TRUE
		
		BZero @buf
		BZero commandType

		GetClient
		mov ebx,[eax].clientSocket
		invoke recv,ebx,addr @buf,BUF_SIZE - 1,0

		; client has close the socket
		.IF eax==0
			GetClient
			INVOKE closesocket,[eax].clientSocket

			GetClient
			mov [eax].clientSocket,-1
			.break
		.ENDIF
		invoke printf,addr @buf


		;TODO handle request
		INVOKE sscanf,addr @buf,addr argsFormat,addr commandType;

		invoke lstrcmp,addr REGISTER_COMMAND,addr commandType
		.if eax==0
			invoke handle_register,client,addr @buf
		.endif

		; handle LOGIN
		invoke lstrcmp,addr LOGIN_COMMAND,addr commandType
		.if eax ==0
			invoke handle_login,client,addr @buf
		.endif

		; handle send text
		invoke lstrcmp,addr SEND_TEXT_COMMAND,addr commandType
		.if eax==0
			invoke handle_send_message,client,addr @buf
		.endif

		; handle send image
		invoke lstrcmp,addr SEND_IMAGE_COMMAND,addr commandType
		.if eax==0
			invoke handle_send_image,client,addr @buf
		.endif

		invoke lstrcmp,addr GET_FRIENDS_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_friends,client,addr @buf
		.endif

		invoke lstrcmp,addr GET_MESSAGES_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_messages,client,addr @buf
		.endif

	.ENDW

	ret
handle_request ENDP

init_server PROC
	local @sock_addr:sockaddr_in

	invoke WSAStartup,wVersion,addr wsaData

	invoke socket,AF_INET,SOCK_STREAM,IPPROTO_TCP
	.if eax == INVALID_SOCKET
		invoke WSAGetLastError
		invoke printf ,addr debugNumFormat,eax
	.ENDIF


	mov listenSocket,eax
	invoke RtlZeroMemory,addr @sock_addr,sizeof @sock_addr
	invoke htons,PORT
	mov @sock_addr.sin_port,ax
	mov @sock_addr.sin_family,AF_INET
	mov @sock_addr.sin_addr,INADDR_ANY
	invoke bind,listenSocket,addr @sock_addr,sizeof @sock_addr
	
	invoke listen,listenSocket,10
	.while 1
		invoke accept,listenSocket,NULL,0
		.if eax==INVALID_SOCKET
			.break
		.endif
		push ecx
		invoke CreateThread,NULL,0,offset handle_request,eax,NULL,esp
		pop ecx
		invoke CloseHandle,eax
	.endw
	invoke closesocket,listenSocket

	ret
init_server ENDP

main PROC
	INVOKE GetProcessHeap
	mov hHeap,eax
	invoke init_server
	invoke printf,offset greetMsg
main endp
end main
