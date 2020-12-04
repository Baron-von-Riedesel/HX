
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	.nolist
	.nocref
	include windef.inc
	include winbase.inc
	include winsock.inc
	include macros.inc
	.cref
	.list

?DEFNAME	equ 0

WSADESCRIPTION_LEN	EQU 256
WSASYS_STATUS_LEN	EQU 128

WSA_INVALID_EVENT		EQU	< NULL >
WSA_INVALID_HANDLE		EQU	< ERROR_INVALID_HANDLE >
WSA_INVALID_PARAMETER	EQU	< ERROR_INVALID_PARAMETER >
WSA_NOT_ENOUGH_MEMORY	EQU	< ERROR_NOT_ENOUGH_MEMORY >
WSA_OPERATION_ABORTED	EQU	< ERROR_OPERATION_ABORTED >

WSADATA struct 
wVersion		WORD	?
wHighVersion	WORD	?
szDescription	SBYTE WSADESCRIPTION_LEN+1 dup (?)
szSystemStatus	SBYTE WSASYS_STATUS_LEN+1 dup (?)
iMaxSockets		WORD	?
iMaxUdpDg		WORD	?
lpVendorInfo	DWORD	?
WSADATA ends

	.DATA

g_hLib	dd 0
g_dwCnt	dd 0

DEFEXP struct
if ?DEFNAME
pszName dd ?
endif
num		dd ?
DEFEXP ends

@DefEx macro name, num
if ?DEFNAME
	DEFEXP {CStr(name), num}
else
	DEFEXP {num}
endif
	endm

exports label dword
	@DefEx "accept",             1
	@DefEx "bind",               2
	@DefEx "closesocket",        3
	@DefEx "connect",            4
	@DefEx "getpeername",        5
	@DefEx "getsockname",        6
	@DefEx "getsockopt",         7
	@DefEx "htonl",              8
	@DefEx "htons",              9
	@DefEx "inet_addr",         10
	@DefEx "inet_ntoa",         11
	@DefEx "ioctlsocket",       12
	@DefEx "listen",            13
	@DefEx "ntohl",             14
	@DefEx "ntohs",             15
	@DefEx "recv",              16
	@DefEx "recvfrom",          17
	@DefEx "select",            18
	@DefEx "send",              19
	@DefEx "sendto",            20
	@DefEx "setsockopt",        21
	@DefEx "shutdown",          22
	@DefEx "socket",            23
	@DefEx "gethostbyaddr",       51
	@DefEx "gethostbyname",       52
	@DefEx "getprotobyname",      53 
	@DefEx "getprotobynumber",    54 
	@DefEx "getservbyname",       55 
	@DefEx "getservbyport",       56
	@DefEx "gethostname",         57
	@DefEx "WSAAsyncSelect",         101
	@DefEx "WSAAsyncGetHostByName",  103
	@DefEx "WSACancelAsyncRequest",  108
	@DefEx "WSASetBlockingHook",     109
	@DefEx "WSAUnhookBlockingHook",  110
	@DefEx "WSAGetLastError",        111
	@DefEx "WSASetLastError",        112
	@DefEx "WSACancelBlockingCall",  113
	@DefEx "WSAIsBlocking",          114
	@DefEx "WSAStartup",             115
	@DefEx "WSACleanup",             116
	@DefEx "__WSAFDIsSet",           151
	dd 0

wsockexp dd 152 dup (0)

	.CODE

LoadExports proc uses esi

	mov esi, offset exports
	.while (dword ptr [esi])
		mov eax, [esi].DEFEXP.num
		invoke GetProcAddress, g_hLib, eax
		mov edx, [esi].DEFEXP.num
		mov [edx*4+offset wsockexp], eax
		add esi, sizeof DEFEXP
	.endw
	ret
	align 4

LoadExports endp

DllMain proc public handle:dword,reason:dword,reserved:dword

	.if (reason == DLL_PROCESS_ATTACH)
		.if (!g_hLib)
			invoke LoadLibrary, CStr("WSOCK32.DLL")
			mov g_hLib, eax
			.if (!eax)
				jmp exit
			.endif
			mov g_dwCnt, 1
			invoke LoadExports
		.else
			inc g_dwCnt
		.endif
	.elseif (reason == DLL_PROCESS_DETACH)
		.if (g_hLib)
			dec g_dwCnt
			.if (ZERO?)
				invoke FreeLibrary, g_hLib
				mov g_hLib, 0
			.endif
		.endif
	.endif
	@mov eax,1
exit:
	ret
	align 4

DllMain endp

_WSAStartup proc stdcall public wVersion:dword, lpWSAData: ptr WSADATA

	push lpWSAData
	push wVersion
	call dword ptr wsockexp[115*4]
	.if (!eax)
		mov  ecx, lpWSAData
		mov  [ecx].WSADATA.wVersion, 0002h
	.endif
	@strace <"WSAStartup(", wVersion, ", ", lpWSAData, ")=",  eax>
	ret
	align 4

_WSAStartup endp

	option prologue:none
	option epilogue:none

@DefProc macro name, num
	align 4
_&name proc public
	@trace <"ws2_32.">
	@tracedw num
	@trace <13,10>
	jmp dword ptr [wsockexp+num*4]
_&name endp
	endm

;--- in WSOCK32, 3 export numbers differ!!!
;---
;---              WSOCK32       WS2_32
;---------------------------------------
;--- inet_addr        10           11
;--- inet_ntoa        11           12
;--- ioctlsocket      12           10

	@DefProc accept,      1
	@DefProc bind,        2
	@DefProc closesocket, 3
	@DefProc connect,     4
	@DefProc getpeername, 5
	@DefProc getsockname, 6
	@DefProc getsockopt,  7
	@DefProc htonl,       8
	@DefProc htons,       9
	@DefProc inet_addr,   10
	@DefProc inet_ntoa,   11
	@DefProc ioctlsocket, 12
	@DefProc listen,      13
	@DefProc ntohl,       14
	@DefProc ntohs,       15
	@DefProc recv,        16
	@DefProc recvfrom,    17
	@DefProc select,      18
	@DefProc send,        19
	@DefProc sendto,      20
	@DefProc setsockopt,  21
	@DefProc shutdown,    22
	@DefProc socket,      23

	@DefProc gethostbyaddr,      51
	@DefProc gethostbyname,      52
	@DefProc getprotobyname,     53
	@DefProc getprotobynumber,   54
	@DefProc getservbyname,      55
	@DefProc getservbyport,      56
	@DefProc gethostname,        57

	@DefProc WSAAsyncSelect,       101
	@DefProc WSAAsyncGetHostByName,103
	@DefProc WSACancelAsyncRequest,108
	@DefProc WSASetBlockingHook,   109
	@DefProc WSAUnhookBlockingHook,110
	@DefProc WSAGetLastError,      111
	@DefProc WSASetLastError,      112
	@DefProc WSACancelBlockingCall,113
	@DefProc WSAIsBlocking,        114
;	@DefProc WSAStartup,           115
	@DefProc WSACleanup,           116

	@DefProc __WSAFDIsSet,         151

	option prologue:prologuedef
	option epilogue:epiloguedef

;--- lpAddress is a SOCKADDR ptr,
;--- lpAddressLength may return required length of lpAddress if too small

WSAStringToAddressA proc public AddressString:ptr BYTE, 
	AddressFamily:dword, lpProtocolInfo:ptr , lpAddress:ptr DWORD, 
	lpAddressLength:ptr DWORD

	mov eax, WSAEBADF
	@strace <"WSAStringToAddressA(", AddressString, ", ", AddressFamily, ", ", lpProtocolInfo, ", ", lpAddress, ", ", lpAddressLength, ")=", eax, " ( unsupp )">
	ret
	align 4

WSAStringToAddressA endp

WSACreateEvent proc public

	invoke CreateEvent, 0, 1, 0, 0
	.if (!eax)
		push WSA_NOT_ENOUGH_MEMORY
		call _WSASetLastError
		mov eax, WSA_INVALID_EVENT
	.endif
	@strace <"WSACreateEvent()=", eax>
	ret
	align 4

WSACreateEvent endp

WSACloseEvent proc public hEvent:DWORD

	invoke CloseHandle, hEvent
	.if (eax)
		mov eax, TRUE
	.else
		push WSA_INVALID_HANDLE
		call _WSASetLastError
		xor eax, eax
	.endif
	@strace <"WSACloseEvent(", hEvent, ")=", eax>
	ret
	align 4

WSACloseEvent endp

WSAResetEvent proc public evnt:dword

	invoke ResetEvent, evnt
	.if (eax)
		mov eax, TRUE
	.else
		push WSA_INVALID_HANDLE
		call _WSASetLastError
		xor eax, eax
	.endif
	@strace <"WSAResetEvent(", evnt, ")=", eax>
	ret
	align 4

WSAResetEvent endp

;--- WSAEventSelect() is a slighly modified WSAAsyncSelect()

WSAEventSelect proc public sock:dword, evnt:dword, lNetworkEvents:dword

	push WSAEFAULT
	call _WSASetLastError 
	mov eax, SOCKET_ERROR
	@strace <"WSAEventSelect(", sock, ", ", evnt, ", ", lNetworkEvents, ")=", eax, " ( unsupp )">
	ret
	align 4

WSAEventSelect endp

WSAEnumNetworkEvents proc public sock:dword, evnt:dword, lpevt:ptr

	push WSAEFAULT
	call _WSASetLastError 
	mov eax, SOCKET_ERROR
	@strace <"WSAEnumNetworkEvents(", sock, ", ", evnt, ", ", lpevt, ")=", eax, " ( unsupp )">
	ret
	align 4

WSAEnumNetworkEvents endp

WSASocketA proc public af:dword, type_:dword, protocol:dword, lpProtocolInfo:dword, g:dword, dwFlags:dword

	push protocol
	push type_
	push af
	call _socket
	@strace <"WSASocketA(", af, ", ", type_, ", ", protocol, ", ", lpProtocolInfo, ", ", g, ", ", dwFlags, ")=", eax>
	ret
	align 4

WSASocketA endp

WSAIoctl proc public sock:dword, dwIoControlCode:dword, lpvInBuffer:ptr, cbInBuffer:dword, lpvOutBuffer:ptr, cbOutBuffer:dword, lpcbBytesReturned:ptr DWORD, lpOverlapped:ptr, lpCompletionRoutine:ptr

	push WSAEFAULT
	call _WSASetLastError 
	mov eax, SOCKET_ERROR
	@strace <"WSAIoctl(", sock, ", ", dwIoControlCode, ", ", lpvInBuffer, ", ", cbInBuffer, ", ", lpvOutBuffer, ", ", cbOutBuffer, ", ", lpcbBytesReturned, ", ", lpOverlapped, ", ", lpCompletionRoutine, ")=", eax, " ( unsupp )">
	ret
	align 4

WSAIoctl endp

WSAAddressToStringA proc public lpsaAddress:dword, dwAddressLength:dword, lpProtocolInfo:ptr, lpszAddressString:dword, lpdwAddressStringLength:ptr DWORD

	push WSAEFAULT
	call _WSASetLastError 
	mov eax, SOCKET_ERROR
	@strace <"WSAAddressToStringA(", lpsaAddress, ", ", dwAddressLength, ", ", lpProtocolInfo, ", ", lpszAddressString, ", ", lpdwAddressStringLength, ")=", eax, " ( unsupp )">
	ret
	align 4

WSAAddressToStringA endp

	end DllMain
