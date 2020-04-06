
;*** DKRNL32.DLL uses dynamic load features from DPMILD32
;*** so LoadLibrary, FreeLibrary and GetProcAddress
;*** all end up in int 21h, AX=4BXX calls

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.CODE

if ?FLAT

LoadLibraryA proc public fname:ptr byte

	invoke LoadLibraryExA, fname, 0, 0
	@strace <"LoadLibraryA(", fname, ")=", eax>
	ret
	align 4
LoadLibraryA endp

FreeLibrary proc public hModule:dword

	mov edx,hModule
	mov ax,4B80h
	int 21h
	@strace <"FreeLibrary(", hModule, ")=", eax>
	ret
	align 4

FreeLibrary endp

GetProcAddress proc public uses ebx hModule:dword, pName:dword

	mov ebx,hModule
	mov edx,pName
	mov ax,4B81h
	int 21h
	@trace <"GetProcAddress(">
	@tracedw hModule
	@trace <", ">
ifdef _DEBUG
	.if (pName & 0FFFF0000h)
		@trace pName
	.else
		@tracedw pName
	.endif
endif
	@trace <")=">
	@tracedw eax
	@trace <13,10>
	ret
	align 4

GetProcAddress endp

endif

	end

