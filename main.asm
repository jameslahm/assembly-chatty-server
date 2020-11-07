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
include       comdlg32.inc
includelib    comdlg32.lib

includelib      msvcrt.lib
printf          PROTO C :ptr sbyte, :VARARG
scanf           PROTO C :ptr sbyte, :VARARG
sscanf          PROTO C :ptr byte,:ptr sbyte,:VARARG
sprintf         PROTO C :ptr byte,:ptr sbyte,:VARARG
srand           PROTO C :dword
rand            PROTO C
time	        PROTO C :ptr dword

;常量定义
BUF_SIZE = 409


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

SQLITE_LAST_INSERT_ROWID_PROTO typedef proto :dword
SQLITE_LAST_INSERT_ROWID typedef ptr SQLITE_LAST_INSERT_ROWID_PROTO

SQLITE_SLCT_PROTO  typedef proto :dword,:dword,:dword,:dword,:dword,:dword
SQLITE_SLCT  typedef ptr   SQLITE_SLCT_PROTO

SQLITE_FREE_TABLE_PROTO typedef proto:dword
SQLITE_FREE_TABLE typedef ptr SQLITE_FREE_TABLE_PROTO


; 数据结构定义
User STRUCT
	id	DWORD -1;户id
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

;content_type 1 - TEXT 2 - IMAGE

; sqlite 相关数据
.data
; 动态链接sqlite库地址
sqlite_lib         DWORD 0
; sqlite db地址
hDB          DWORD 0
sqlite_open       SQLITE_OPEN  ?
sqlite_close      SQLITE_CLOSE ?
sqlite_exec       SQLITE_EXEC ?
sqlite_last_insert_rowid SQLITE_LAST_INSERT_ROWID ?
sqlite_slct        SQLITE_SLCT ?
sqlite_free_table SQLITE_FREE_TABLE ?

; SQLITEite 常量
libName BYTE "sqlite3.dll",0
sqlite3_open  BYTE  "sqlite3_open",0
sqlite3_close BYTE  "sqlite3_close",0
sqlite3_exec  BYTE  "sqlite3_exec",0
sqlite3_slct  BYTE  "sqlite3_get_table",0 
sqlite3_last_insert_rowid BYTE "sqlite3_last_insert_rowid",0
sqlite3_free_table BYTE "sqlite3_free_table",0
databaseFileName      BYTE  "data.sqlite",0  
errorInfo     DWORD ?

; create table SQLITE
createUserTableSql  BYTE    "create table if not exists users(id integer primary key autoincrement,",
							"username varchar(30),password varchar(30),avatar varchar(120));",0 
createMessageTableSql BYTE   "create table if not exists messages(id integer primary key autoincrement,",
								"is_read integer,sender_id integer,receiver_id integer,content_type integer,content varchar(200));",0

createFriendTableSql BYTE "create table if not exists friends(id integer primary key autoincrement,",
								"friend1_id integer,friend2_id integer);",0

; insert data SQLITE
insertUserSql    BYTE    "insert into users(username,password) values(",22h,"%s",22h,",",22h,"%s",22h,");",0
insertFriendSql   BYTE   "insert into friends(friend1_id,friend2_id) values(%d,%d);",0
insertMessageSql BYTE    "insert into messages(sender_id,receiver_id,content_type,content,is_read) values(%d,%d,%d,",22h,"%s",22h,",%d);",0

; select data SQLITE
verifyUserSql  BYTE "select id,username,password from users where username=",22h,"%s",22h," and password=",22h,"%s",22h,";",0
getFriendsSql    BYTE "select friend1_id,friend2_id from friends where friend1_id = %d or friend2_id=%d",0
getMessagesSql BYTE "select sender_id,content_type,content from messages where sender_id = %d and receiver_id = %d or sender_id=%d and receiver_id = %d;",0
getLastMessagesSql BYTE "select content_type,content from messages where sender_id = %d and receiver_id = %d and is_read = 0;",0
getUserSql BYTE "select username from users where id=%d",0
getUsersSql BYTE "select id,username from users",0

; update data SQLITE
updateIsReadSql BYTE "update messages set is_read = 1 where sender_id = %d and receiver_id = %d ;",0

; WSAData init
wsaData WSADATA <>
wVersion WORD 0202h

; listen socket
listenSocket  dword 0

greetMsg BYTE "Starting Server...",0dh,0ah,0

; parse Args
argsFormat BYTE "%s",0

loginArgsFormat BYTE "%s %s %s",0
sendTextArgsFormat BYTE "%s %d %[^",0dh,0ah,"]",0
sendImageArgsFormat BYTE "%s %d %d",0
addFriendArgsFormat BYTE "%s %d",0
getMessagesArgsFormat BYTE "%s %d",0
getLastMessagesArgsFormat BYTE "%s %d",0

; command constants
REGISTER_COMMAND BYTE "REGISTER",0
LOGIN_COMMAND BYTE "LOGIN",0
SEND_TEXT_COMMAND BYTE "TEXT",0
SEND_IMAGE_COMMAND BYTE "IMAGE",0
GET_FRIENDS_COMMAND BYTE "FRIENDS",0
ADD_FRIEND_COMMAND BYTE "ADDFRIEND",0
GET_MESSAGES_COMMAND BYTE "MESSAGES",0
GET_USERS_COMMAND BYTE "USERS",0
GET_LASTMESSAGES_COMMAND BYTE "LASTMESSAGES",0

; logs print format
debugFormat BYTE "DEBUG!!",0dh,0ah,0
debugStrFormat BYTE "DEBUG %s",0dh,0ah,0
debugNumFormat BYTE "DEBUG %d",0dh,0ah,0
registerLogFormat BYTE "User %s(id:%d password:%s) register",0dh,0ah,0
loginLogFormat BYTE "User %s(id:%d password:%s) login",0dh,0ah,0
sendTextLogFormat BYTE "User %s send %s(text) to %d",0dh,0ah,0
sendImageLogFormat BYTE "User %s send %s(image:%d) to %d",0dh,0ah,0
addFriendLogFormat BYTE "User %s add friend %d",0dh,0ah,0

; response message
successResponse BYTE "SUCCESS",0dh,0ah,0
successResponseLen DWORD 9
failureResponse BYTE "ERROR",0dh,0ah,0
failureResponseLen DWORD 7
friendsNumResponseFormat BYTE "FRIENDS %d",0dh,0ah,0
friendsResponseFormat BYTE "%d %s",0dh,0ah,0
usersNumResponseFormat BYTE "USERS %d",0dh,0ah,0
usersResponseFormat BYTE "%d %s",0dh,0ah,0

messagesNumResponseFormat BYTE "MESSAGES %d",0dh,0ah,0
textResponseFormat BYTE "TEXT %d %s",0dh,0ah,0
imageResponseFormat BYTE "IMAGE %d %d",0dh,0ah,0

; all clients
clients Client 50 dup(<>)
fakeId DWORD 1

; heap handle
hHeap DWORD ?

toNumFormat BYTE "%d",0
toStrFormat BYTE "%s",0
toNumStrFormat BYTE "%d %s",0

FAKE_SEED DWORD 0


GetClient MACRO client:=<client>
	mov eax,client
	assume eax:ptr Client
ENDM

BZero MACRO buf:=<buf>,bufSize:=<BUF_SIZE>
	INVOKE RtlZeroMemory,addr buf,bufSize
ENDM

CheckUser MACRO client:=<client>
	mov eax,client
	assume eax:ptr Client
	push [eax].user.id
	pop ebx
	.if ebx==-1
		GetClient
		invoke send,[eax].clientSocket,addr failureResponse,failureResponseLen,0
		jmp handleRequestExit
	.endif
ENDM


.code
init_db PROC
	push ebp
	mov ebp,esp

	invoke   LoadLibrary,offset libName
	mov      sqlite_lib,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_open
	mov		 sqlite_open,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_close
	mov      sqlite_close,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_exec
	mov		 sqlite_exec,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_last_insert_rowid
	mov      sqlite_last_insert_rowid,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_slct
	mov		 sqlite_slct,eax
	invoke   GetProcAddress,sqlite_lib,addr sqlite3_free_table
	mov sqlite_free_table,eax
	invoke   sqlite_open,offset databaseFileName,offset hDB

	invoke   sqlite_exec,hDB,addr createUserTableSql,NULL,NULL,offset errorInfo
	invoke   sqlite_exec,hDB,addr createMessageTableSql,NULL,NULL,offset errorInfo
	invoke   sqlite_exec,hDB,addr createFriendTableSql,NULL,NULL,offset errorInfo

	leave
	ret
init_db ENDP

getClientById PROC receiverId:DWORD
	mov eax,offset clients
	assume eax:ptr Client
	.WHILE TRUE
		mov ebx,[eax].user.id
		.if ebx == receiverId 
			assume eax:nothing
			.BREAK
		.else
			add eax,sizeof Client
		.endif
	.ENDW
	ret
getClientById ENDP


handle_login PROC client:ptr Client,@bufAddr:ptr BYTE 
	local commandType[BUF_SIZE]:byte
	local sqlBuf[BUF_SIZE]:byte
	local row:DWORD
	local column:DWORD
	local result:DWORD
	local id:DWORD

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sscanf,@bufAddr,addr loginArgsFormat,addr commandType,ebx,ecx
	
	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sprintf,addr sqlBuf,addr verifyUserSql,ebx,ecx

	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_slct,hDB,addr sqlBuf,addr result,addr row,addr column,offset errorInfo

	.if eax!=0
		invoke printf,addr debugStrFormat,errorInfo
	.endif

	.if row == 1
		mov ebx,result
		mov edx,column
		mov ecx,[ebx+4*edx]

		invoke sscanf,ecx,addr toNumFormat,addr id
		GetClient
		push id
		pop [eax].user.id

		GetClient
		lea ebx,[eax].user.username
		lea ecx,[eax].user.password
		mov edx,[eax].user.id
		invoke printf,addr loginLogFormat,ebx,edx,ecx

		GetClient
		invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0
	.else
		GetClient
		invoke send,[eax].clientSocket,addr failureResponse,failureResponseLen,0
	.endif

	invoke sqlite_free_table,result
	assume eax:nothing
	ret
handle_login ENDP

handle_register PROC client:ptr Client,@bufAddr:ptr BYTE 
	local commandType[BUF_SIZE]:byte
	local sqlBuf[BUF_SIZE]:byte

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sscanf,@bufAddr,addr loginArgsFormat,addr commandType,ebx,ecx

	; insert user to database
	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke sprintf,addr sqlBuf,addr insertUserSql,ebx,ecx

	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,addr errorInfo
	.if eax!=0
		invoke printf,addr debugStrFormat,errorInfo
	.endif

	invoke sqlite_last_insert_rowid,hDB
	mov ebx,eax
	GetClient
	mov [eax].user.id,ebx

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	mov edx,[eax].user.id
	invoke printf,addr registerLogFormat,ebx,edx,ecx

	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	assume eax:nothing
	ret
handle_register ENDP

handle_add_friend PROC client:ptr Client,@bufAddr:ptr BYTE
	local friendId:DWORD
	local commandType[BUF_SIZE]:BYTE
	local sqlBuf[BUF_SIZE]:BYTE

	BZero commandType
	BZero sqlBuf

	invoke sscanf,@bufAddr,addr addFriendArgsFormat,addr commandType,addr friendId

	GetClient
	invoke sprintf,addr sqlBuf,addr insertFriendSql,[eax].user.id,friendId

	GetClient
	lea ebx,[eax].user.username
	invoke printf,addr addFriendLogFormat,ebx,friendId

	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,addr errorInfo
	.if eax!=0
		invoke printf,addr debugStrFormat,errorInfo
	.endif

	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	assume eax:nothing
	
	ret
handle_add_friend ENDP

handle_get_users PROC client:ptr Clinet,@bufAddr:ptr BYTE
	local result:DWORD
	local column:DWORD
	local row:DWORD
	local usersNumResponseBuf[BUF_SIZE]:BYTE
	local index:DWORD
	local id:DWORD
	local username[BUF_SIZE]:BYTE
	local usersResponseBuf[BUF_SIZE]:BYTE

	BZero username
	BZero usersResponseBuf
	BZero usersNumResponseBuf

	invoke printf,addr debugStrFormat,addr getUsersSql
	invoke sqlite_slct,hDB,addr getUsersSql,addr result,addr row,addr column,offset errorInfo

	invoke sprintf,addr usersNumResponseBuf,addr usersNumResponseFormat,row

	invoke lstrlen,addr usersNumResponseBuf

	mov ebx,eax

	GetClient
	mov ecx,[eax].clientSocket
	invoke send,ecx,addr usersNumResponseBuf,ebx,0

	push column
	pop index

	mov ecx,1
	.WHILE ecx<=row
		push ecx
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toNumFormat,addr id

		inc index
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toStrFormat,addr username

		BZero usersResponseBuf
		invoke sprintf,addr usersResponseBuf,addr usersResponseFormat,id,addr username

		invoke lstrlen,addr usersResponseBuf
		mov ecx,eax

		GetClient
		mov ebx,[eax].clientSocket
		invoke send,ebx,addr usersResponseBuf,ecx,0

		inc index
		pop ecx
		inc ecx
	.ENDW

	invoke sqlite_free_table,result
	ret
handle_get_users ENDP

handle_get_friends PROC client:ptr Client,@bufAddr:ptr BYTE 
	local sqlBuf[BUF_SIZE]:BYTE
	local row:DWORD
	local column:DWORD
	local result:DWORD
	local index:DWORD
	local tmpId:DWORD
	local sqlBuf2[BUF_SIZE]:BYTE
	local row2:DWORD
	local column2:DWORD
	local result2:DWORD
	local friendsNumResponseBuf[BUF_SIZE]:BYTE
	local friendsResponseBuf[BUF_SIZE]:BYTE
	local count:DWORD

	BZero sqlBuf
	BZero sqlBuf2
	BZero friendsNumResponseBuf
	BZero friendsResponseBuf

	GetClient
	mov ebx,[eax].user.id
	invoke sprintf,addr sqlBuf,addr getFriendsSql,ebx,ebx

	invoke printf,addr debugStrFormat,addr sqlBuf
	invoke sqlite_slct,hDB,addr sqlBuf,addr result,addr row,addr column,offset errorInfo


	invoke sprintf,addr friendsNumResponseBuf,addr friendsNumResponseFormat,row

	invoke lstrlen,addr friendsNumResponseBuf
	mov ebx,eax

	GetClient
	mov ecx,[eax].clientSocket
	invoke send,ecx,addr friendsNumResponseBuf,ebx,0

	push column
	pop index
	
	mov count,1
	mov ecx,count
	.WHILE ecx <= row
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toNumFormat,addr tmpId
		GetClient
		mov edx,[eax].user.id
		.if tmpId == edx
			inc index
			mov ebx,result
			mov edx,index
			mov ecx,[ebx+4*edx]
			invoke sscanf,ecx,addr toNumFormat,addr tmpId
		.else
			inc index
		.endif

		BZero sqlBuf2

		invoke sprintf,addr sqlBuf2,addr getUserSql,tmpId

		invoke printf,addr debugStrFormat,addr sqlBuf2

		invoke sqlite_slct,hDB,addr sqlBuf2,addr result2,addr row2,addr column2,offset errorInfo
		
		mov ebx,result2
		mov edx,column2
		mov ecx,[ebx+4*edx]
		invoke sprintf,addr friendsResponseBuf,addr friendsResponseFormat,tmpId,ecx

		invoke lstrlen,addr friendsResponseBuf
		mov ebx,eax

		GetClient
		mov ecx,[eax].clientSocket
		invoke send ,ecx,addr friendsResponseBuf,ebx,0

		inc index
		inc count
		mov ecx,count
	.ENDW

	.if row>=1
		invoke sqlite_free_table,result2
	.endif

	invoke sqlite_free_table,result
	ret

handle_get_friends ENDP

get_messages PROC client:ptr Client,senderId:DWORD,receiverId:DWORD
	local sqlBuf[BUF_SIZE]:BYTE
	local row:DWORD
	local column:DWORD
	local result:DWORD
	local index:DWORD
	local content_type:DWORD
	local responseBuf[BUF_SIZE]:BYTE
	local content[BUF_SIZE]:BYTE
	local fileHandle:DWORD
	local imageSize:DWORD
	local imageBuf[BUF_SIZE]:DWORD
	local bytesRead:DWORD
	local isRecv:DWORD
	local tmpSenderId:DWORD


	BZero sqlBuf
	BZero responseBuf

	invoke sprintf,addr sqlBuf,addr getMessagesSql,senderId,receiverId,receiverId,senderId

	invoke printf,addr debugStrFormat,addr sqlBuf


	invoke sqlite_slct,hDB,addr sqlBuf,addr result,addr row,addr column,offset errorInfo

	invoke sprintf,addr responseBuf,addr messagesNumResponseFormat,row

	invoke lstrlen,addr responseBuf
	mov ebx,eax

	GetClient
	mov ecx,[eax].clientSocket
	invoke send,ecx,addr responseBuf,ebx,0

	push column
	pop index
	
	mov ecx,1
	.WHILE ecx <= row
		push ecx
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toNumFormat,addr tmpSenderId
		
		mov eax,tmpSenderId
		.if eax == senderId
			mov isRecv,0
		.else
			mov isRecv,1
		.endif

		inc index
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toNumFormat,addr content_type
		
		inc index
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toStrFormat,addr content

		.if content_type == 1
			BZero responseBuf
			invoke sprintf,addr responseBuf,addr textResponseFormat,isRecv,addr content

			invoke lstrlen,addr responseBuf
			mov ecx,eax

			GetClient
			mov ebx,[eax].clientSocket
			invoke send,ebx,addr responseBuf,ecx,0

			invoke printf,addr debugStrFormat,addr responseBuf

		.else
			invoke printf,addr debugStrFormat,addr content
			invoke CreateFile,addr content,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
			mov fileHandle,eax

			invoke GetFileSize,fileHandle,addr imageSize
			mov imageSize,eax

			BZero responseBuf
			invoke sprintf,addr responseBuf,addr imageResponseFormat,isRecv,imageSize
			
			invoke lstrlen,addr responseBuf
			mov ebx,eax

			GetClient
			mov ecx,[eax].clientSocket
			invoke send,ecx,addr responseBuf,ebx,0
			invoke printf,addr debugStrFormat,addr responseBuf


			.WHILE TRUE
				BZero imageBuf
				invoke ReadFile,fileHandle,addr imageBuf,BUF_SIZE-1,addr bytesRead,NULL

				.if eax==0
					invoke GetLastError
					invoke printf,addr debugNumFormat,eax
				.endif

				GetClient
				mov ebx,[eax].clientSocket
				invoke send,ebx,addr imageBuf,bytesRead,0

				mov eax,bytesRead
				.if eax < BUF_SIZE -1
					.BREAK
				.endif
			.ENDW

			invoke CloseHandle,fileHandle

		.endif

		inc index
		pop ecx
		inc ecx
	.ENDW
	invoke sqlite_free_table,result

	BZero sqlBuf
	invoke sprintf,addr sqlBuf,addr updateIsReadSql,receiverId,senderId
	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,offset errorInfo

	ret
get_messages ENDP

get_last_messages PROC client:ptr Client,senderId:DWORD,receiverId:DWORD
	local sqlBuf[BUF_SIZE]:BYTE
	local row:DWORD
	local column:DWORD
	local result:DWORD
	local index:DWORD
	local content_type:DWORD
	local responseBuf[BUF_SIZE]:BYTE
	local content[BUF_SIZE]:BYTE
	local fileHandle:DWORD
	local imageSize:DWORD
	local imageBuf[BUF_SIZE]:DWORD
	local bytesRead:DWORD
	local isRecv:DWORD

	BZero sqlBuf
	BZero responseBuf
	mov isRecv,1

	invoke sprintf,addr sqlBuf,addr getLastMessagesSql,senderId,receiverId
	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_slct,hDB,addr sqlBuf,addr result,addr row,addr column,offset errorInfo

	invoke sprintf,addr responseBuf,addr messagesNumResponseFormat,row

	invoke lstrlen,addr responseBuf
	mov ebx,eax

	GetClient
	mov ecx,[eax].clientSocket
	invoke send,ecx,addr responseBuf,ebx,0

	push column
	pop index
	
	mov ecx,1
	.WHILE ecx <= row
		push ecx
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toNumFormat,addr content_type
		
		inc index
		mov ebx,result
		mov edx,index
		mov ecx,[ebx+4*edx]
		invoke sscanf,ecx,addr toStrFormat,addr content

		.if content_type == 1
			BZero responseBuf
			invoke sprintf,addr responseBuf,addr textResponseFormat,isRecv,addr content
			
			invoke lstrlen,addr responseBuf
			mov ecx,eax

			GetClient
			mov ebx,[eax].clientSocket
			invoke send,ebx,addr responseBuf,ecx,0
		.else
			invoke CreateFile,addr content,GENERIC_READ,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
			mov fileHandle,eax

			invoke GetFileSize,fileHandle,addr imageSize
			mov imageSize,eax

			BZero responseBuf
			invoke sprintf,addr responseBuf,addr imageResponseFormat,isRecv,imageSize
			
			invoke lstrlen,addr responseBuf
			mov ebx,eax

			GetClient
			mov ecx,[eax].clientSocket
			invoke send,ecx,addr responseBuf,ebx,0

			.WHILE TRUE
				BZero imageBuf
				invoke ReadFile,fileHandle,addr imageBuf,BUF_SIZE-1,addr bytesRead,NULL

				GetClient
				mov ebx,[eax].clientSocket
				invoke send,ebx,addr imageBuf,bytesRead,0

				mov eax,bytesRead
				.if eax < BUF_SIZE -1
					.BREAK
				.endif
			.ENDW

			invoke CloseHandle,fileHandle

		.endif

		inc index
		pop ecx
		inc ecx
	.ENDW
	invoke sqlite_free_table,result

	BZero sqlBuf
	invoke sprintf,addr sqlBuf,addr updateIsReadSql,senderId,receiverId
	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,offset errorInfo

	ret
get_last_messages ENDP

get_messages_fake PROC client:ptr Client,senderId:DWORD,receiverId:DWORD
	invoke printf,addr debugNumFormat,senderId
	invoke printf,addr debugNumFormat,receiverId
	ret
get_messages_fake ENDP

handle_get_messages PROC client:ptr Client,@bufAddr:ptr BYTE 
	local receiverId:DWORD
	local commandType[BUF_SIZE]:BYTE

	BZero commandType

	invoke sscanf,@bufAddr,addr getMessagesArgsFormat,addr commandType,addr receiverId

	invoke printf,addr debugStrFormat,addr commandType

	GetClient
	mov ebx,[eax].user.id
	invoke get_messages,client,ebx,receiverId

	;GetClient
	;mov ebx,[eax].user.id
	;invoke get_messages,client,receiverId,ebx
	ret
handle_get_messages ENDP

handle_get_last_messages PROC client:ptr Client,@bufAddr:ptr BYTE
	local receiverId:DWORD
	local commandType[BUF_SIZE]:BYTE

	BZero commandType

	invoke sscanf,@bufAddr,addr getMessagesArgsFormat,addr commandType,addr receiverId

	GetClient
	mov ebx,[eax].user.id
	invoke get_last_messages,client,receiverId,ebx

	ret
handle_get_last_messages ENDP

handle_send_message PROC USES eax client:ptr Client,@bufAddr:ptr BYTE
	local commandType[BUF_SIZE]:byte
	local receiverId:DWORD
	local message[BUF_SIZE]:byte
	local sqlBuf[BUF_SIZE]:BYTE
	local contentType:DWORD
	local isRead:DWORD

	BZero sqlBuf
	BZero commandType
	BZero message

	mov contentType,1
	mov isRead,0

	invoke sscanf,@bufAddr,addr sendTextArgsFormat,addr commandType,addr receiverId,addr message

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke printf,addr sendTextLogFormat,ebx,addr message,receiverId


	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	GetClient
	mov ebx,[eax].user.id
	invoke sprintf,addr sqlBuf,addr insertMessageSql,ebx,receiverId,contentType,addr message,isRead

	invoke printf,addr debugStrFormat,addr sqlBuf

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,addr errorInfo

	assume eax:nothing

	ret
handle_send_message ENDP

; 随机生成10位图片文件名
generate_random_image_name PROC buf:ptr BYTE
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

	invoke srand,FAKE_SEED

	mov count,10
	.while count>=1
		invoke rand
		mov edx,0
		mov ecx,26
		div ecx
		mov eax,edx
		add eax,61h
		
		mov ecx,buf
		add ecx,10

		mov edx,count
		mov ebx,10
		sub ebx,edx
		mov [ecx+ebx],al

		dec count
	.endw

	inc FAKE_SEED

	inc ebx
	mov eax,02eh
	mov [ecx+ebx],eax

	inc ebx
	mov eax,062h
	mov [ecx+ebx],eax

	inc ebx
	mov eax,06dh
	mov [ecx+ebx],eax

	inc ebx
	mov eax,070h
	mov [ecx+ebx],eax
	ret
generate_random_image_name ENDP

handle_send_image PROC USES eax client:ptr Client,@bufAddr:ptr BYTE
	local commandType[BUF_SIZE]:byte
	local receiverId:DWORD
	local imageSize:DWORD
	local imageName[BUF_SIZE]:byte
	local imageBuf[BUF_SIZE]:byte
	local hasReceivedSize:dword
	local fileHandle:dword
	local bytesWrite:dword
	local sqlBuf[BUF_SIZE]:DWORD
	local contentType:DWORD
	local isRead:DWORD

	BZero commandType
	BZero imageName
	BZero imageBuf

	mov contentType,2
	mov isRead,0

	invoke sscanf,@bufAddr,addr sendImageArgsFormat,addr commandType,addr receiverId,addr imageSize

	invoke generate_random_image_name, addr imageName

	invoke printf,addr debugStrFormat,addr imageName

	GetClient
	lea ebx,[eax].user.username
	lea ecx,[eax].user.password
	invoke printf,addr sendImageLogFormat,ebx,addr imageName,imageSize,receiverId

	;create image file
	invoke CreateFile,addr imageName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL OR FILE_FLAG_WRITE_THROUGH,0
	mov fileHandle,eax

	; start recv image content
	mov hasReceivedSize,0
	mov eax,imageSize

	.WHILE hasReceivedSize < eax
		push eax
		mov ebx,hasReceivedSize
		mov ecx,eax
		sub ecx,ebx
		.if ecx > BUF_SIZE - 1
			mov ecx,BUF_SIZE -1
		.endif
		GetClient
		mov ebx,[eax].clientSocket
		invoke recv,ebx,addr imageBuf,ecx,0
		add hasReceivedSize,eax
		mov ebx,eax
		invoke WriteFile,fileHandle,addr imageBuf,ebx,addr bytesWrite,NULL
		pop eax
	.endw
	invoke CloseHandle,fileHandle


	GetClient
	invoke send,[eax].clientSocket,addr successResponse,successResponseLen,0

	assume eax:nothing

	GetClient
	mov ebx,[eax].user.id
	invoke sprintf,addr sqlBuf,addr insertMessageSql,ebx,receiverId,contentType,addr imageName,isRead

	invoke sqlite_exec,hDB,addr sqlBuf,NULL,NULL,addr errorInfo
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

		invoke lstrcmp,addr GET_USERS_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_users,client,addr @buf
		.endif

		CheckUser

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

		invoke lstrcmp,addr ADD_FRIEND_COMMAND,addr commandType
		.if eax==0
			invoke handle_add_friend,client,addr @buf
		.endif

		invoke lstrcmp,addr GET_FRIENDS_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_friends,client,addr @buf
		.endif

		invoke lstrcmp,addr GET_MESSAGES_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_messages,client,addr @buf
		.endif

		invoke lstrcmp,addr GET_LASTMESSAGES_COMMAND,addr commandType
		.if eax==0
			invoke handle_get_last_messages,client,addr @buf
		.endif

handleRequestExit:

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
	invoke init_db
	INVOKE GetProcessHeap
	mov hHeap,eax
	invoke printf,offset greetMsg
	invoke init_server
main endp
end main
