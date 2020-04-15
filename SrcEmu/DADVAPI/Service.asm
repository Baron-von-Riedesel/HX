
		.386
if ?FLAT
		.MODEL FLAT, stdcall
else
		.MODEL SMALL, stdcall
endif
		option casemap:none
		option proc:private

		include winbase.inc
		include macros.inc

		.CODE

OpenSCManagerA proc public dw1:ptr BYTE, dw2:ptr BYTE, dw3:DWORD
		xor eax,eax
		@strace <"OpenSCManagerA(", dw1, ", ", dw2, ", ", dw3, ")=", eax, " *** unsupp ***">
		ret
		align 4
OpenSCManagerA endp

OpenSCManagerW proc public dw1:ptr WORD, dw2:ptr WORD, dw3:DWORD
		xor eax,eax
		@strace <"OpenSCManagerW(", dw1, ", ", dw2, ", ", dw3, ")=", eax, " *** unsupp ***">
		ret
		align 4
OpenSCManagerW endp

CreateServiceA proc public hSCManager:DWORD, lpServiceName:DWORD, lpDisplayName:DWORD,
		dwDesiredAccess:DWORD, dwServiceType:DWORD, dwStartType:DWORD, dwErrorControl:DWORD,
		lpBinaryPathName:ptr, lpLoadOrderGroup:ptr, lpdwTagId:ptr, lpDependencies:ptr, 
		lpServiceStartName:ptr, lpPassword:ptr
		xor eax, eax
		@strace <"CreateServiceA(", hSCManager, ", ", lpServiceName, ", ", lpDisplayName, ", ... )=", eax, " *** unsupp ***">
		ret
		align 4
CreateServiceA endp

CloseServiceHandle proc public hService:DWORD
		xor eax,eax
		@strace <"CloseServiceHandle(", hService, ")=", eax, " *** unsupp ***">
		ret
		align 4
CloseServiceHandle endp

OpenServiceA proc public hService:DWORD, lpServiceName:ptr BYTE, dwDesiredAccess:DWORD
		xor eax,eax
		@strace <"OpenServiceA(", hService, ", ", lpServiceName, ", ", dwDesiredAccess, ")=", eax, " *** unsupp ***">
		ret
		align 4
OpenServiceA endp

OpenServiceW proc public hService:DWORD, lpServiceName:ptr WORD, dwDesiredAccess:DWORD
		xor eax,eax
		@strace <"OpenServiceW(", hService, ", ", lpServiceName, ", ", dwDesiredAccess, ")=", eax, " *** unsupp ***">
		ret
		align 4
OpenServiceW endp

DeleteService proc public hService:DWORD
		xor eax,eax
		@strace <"DeleteService(", hService, ")=", eax, " *** unsupp ***">
		ret
		align 4
DeleteService endp

StartServiceA proc public hService:DWORD, dwNumServiceArgs:DWORD, lpServiceArgVectors:ptr ptr
		xor eax,eax
		@strace <"StartServiceA(", hService, ", ", dwNumServiceArgs, ", ", lpServiceArgVectors, ")=", eax, " *** unsupp ***">
		ret
		align 4
StartServiceA endp

ControlService proc public hService:DWORD, dwControl:DWORD, lpServiceStatus:ptr DWORD
		xor eax,eax
		@strace <"ControlService(", hService, ", ", dwControl, ", ", lpServiceStatus, ")=", eax, " *** unsupp ***">
		ret
		align 4
ControlService endp

QueryServiceStatus proc public hService:DWORD, lpServiceStatus:ptr DWORD
		xor eax,eax
		@strace <"QueryServiceStatus(", hService, ", ", lpServiceStatus, ")=", eax, " *** unsupp ***">
		ret
		align 4
QueryServiceStatus endp

		end
