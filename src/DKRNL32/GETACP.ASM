
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

	.DATA

	.CODE

GetACP proc public uses ebx
	mov ax,6601h
	int 21h
	movzx eax,bx
	@strace <"GetACP()=", eax>
	ret
	align 4
GetACP endp

;--- GetConsoleCP returns OEM CP

GetConsoleCP proc public
ifdef _DEBUG
	push ebx
	mov ax,6601h
	int 21h
	movzx eax,bx
	pop ebx
	@strace <"GetConsoleCP()=", eax>
	ret
	align 4
endif
;--- fall thru in nondebug mode
GetConsoleCP endp

;--- GetConsoleOutputCP returns OEM CP

GetConsoleOutputCP proc public
ifdef _DEBUG
	push ebx
	mov ax,6601h
	int 21h
	movzx eax,bx
	pop ebx
	@strace <"GetConsoleOutputCP()=", eax>
	ret
	align 4
endif
;--- fall thru in nondebug mode
GetConsoleOutputCP endp

GetOEMCP proc public uses ebx
	mov ax,6601h
	int 21h
	movzx eax,bx
	@strace <"GetOEMCP()=", eax>
	ret
	align 4
GetOEMCP endp


;--- SetConsoleOutputCP returns OEM CP

SetConsoleOutputCP proc public wCodePageId:DWORD
ifdef _DEBUG
	push ebx
	mov ebx, wCodePageId
	mov edx, ebx
	mov ax,6602h
	int 21h
	@strace <"SetConsoleOutputCP(", wCodePageId, ")=", eax>
	pop ebx
	ret
	align 4
endif
;--- fall thru in nondebug mode
SetConsoleOutputCP endp

;--- SetConsoleCP 

SetConsoleCP proc public uses ebx wCodePageId:DWORD

	mov ebx, wCodePageId
	mov edx, ebx
	mov ax,6602h
	int 21h
	@strace <"SetConsoleCP(", wCodePageId, ")=", eax>
	ret
SetConsoleCP endp

	end

