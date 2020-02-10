
;--- implements GetModuleHandleA()

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

	.DATA

	.CODE

ife ?FLAT
_GetModuleHandle proto :dword, :dword
endif

GetModuleHandleA proc public pName:ptr byte

if ?FLAT
	mov edx,pName		   ;use dpmild32 to get handle
	and edx, edx
	jnz @F
	call GetCurrentProcess
	mov eax,[eax].PROCESS.hModule
	jmp exit
@@:
;	xor eax,eax
;	test [g_bIntFl],IKF_PELDR
;	jz exit
	mov ax,4B82h
	int 21h
else
	mov eax, pName
	push 0
	push eax
	call _GetModuleHandle
endif
exit:
ifdef _DEBUG
	mov ecx, pName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	@strace <"GetModuleHandleA(", &ecx, ")=", eax>
endif
	ret
	align 4
GetModuleHandleA endp

	end
