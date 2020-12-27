
;--- implements GetModuleHandleExA/W()

if ?FLAT
	.386
	.MODEL FLAT, stdcall
	option casemap:none
	option proc:private

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

GET_MODULE_HANDLE_EX_FLAG_PIN equ 1
GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT equ 2
GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS equ 4

	.CODE

GetModuleHandleExA proc public uses ebx dwFlags:dword, lpModuleName:ptr byte, phModule:ptr DWORD

	xor eax,eax
	mov ebx,phModule
	mov [ebx],eax
	test dwFlags, GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
	jnz exit
	mov edx,lpModuleName
	and edx, edx
	jnz @F
	call GetCurrentProcess
	mov eax,[eax].PROCESS.hModule
	mov [ebx],eax
	jmp exit
@@:
	mov ax,4B82h
	int 21h
	mov [ebx],eax
exit:
	ret
	align 4
GetModuleHandleExA endp

GetModuleHandleExW proc public dwFlags:dword, lpModuleName:ptr word, phModule:ptr DWORD
	mov eax, lpModuleName
	.if (eax)
		call ConvertWStr
	.endif
	invoke GetModuleHandleExA, dwFlags, eax, phModule
	ret
	align 4
GetModuleHandleExW endp

endif

	end
