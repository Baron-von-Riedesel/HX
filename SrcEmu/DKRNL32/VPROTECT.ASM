
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

;--- currently can only protect/unprotect pages (if dpmi host is v1.0)

VirtualProtect proc public lpAddr:dword,dwSize:dword,dwReqProt:dword,pOldProt:dword

	xor eax, eax
	.if (eax == pOldProt)
		jmp exit
	.endif
	test dwReqProt, PAGE_READWRITE or PAGE_EXECUTE_READWRITE or PAGE_WRITECOPY or PAGE_EXECUTE_WRITECOPY
	jz @F
	or al, 8
@@:
if ?FLAT
;--- don't allow the header of current app to be protected
;--- it contains some important variables and must be readwrite

	xor edx, edx
	push eax
	mov ax,4B82h
	int 21h
	mov edx, eax
	pop eax
	mov ecx, lpAddr
	cmp edx, ecx
	jb @F
	add ecx, 1000h
	cmp edx, ecx
	jb exit
@@:
endif
	invoke VirtualSetPageAttr, lpAddr, dwSize, eax , 8
exit:
	@strace <"VirtualProtect(", lpAddr, ", ", dwSize, ", ", dwReqProt, ", ", pOldProt, ")=", eax>
	ret
	align 4

VirtualProtect endp

VirtualProtectEx proc public hProcess:dword, lpAddr:dword, dwSize:dword, dwReqProt:dword, pOldProt:ptr dword

	invoke VirtualProtect, lpAddr, dwSize, dwReqProt, pOldProt
	@strace <"VirtualProtectEx(", hProcess, ", ", lpAddr, ", ", dwSize, ", ", dwReqProt, ", ", pOldProt, ")=", eax>
	ret
	align 4
VirtualProtectEx endp

	end
