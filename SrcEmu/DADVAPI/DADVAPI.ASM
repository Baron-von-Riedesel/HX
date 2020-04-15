
	.386
	.MODEL FLAT, stdcall

	option casemap:none

	include winbase.inc
	include macros.inc
	include dadvapi.inc

	.CODE

if ?USEWIN95REGAPI
GetVmmEntry proc
	pushad
	push es
	mov bx,1
	mov ax,1684h
	int 2fh
	jc exit
	mov eax,es
	or ax,di
	jz exit
	movzx edi,di
	mov dword ptr ddVmmEntry+0,edi
	mov word ptr ddVmmEntry+4,es
	or bRegistry, 1
exit:
	pop es
	popad
	ret
	align 4

GetVmmEntry endp
endif

DllMain proc stdcall public hModule:dword,reason:dword,reserved:dword

	.if (reason == DLL_PROCESS_ATTACH)
		invoke DisableThreadLibraryCalls, hModule
if ?USEWIN95REGAPI
		mov ax,1600h
		int 2Fh
		cmp al,00
		jz @F
		call GetVmmEntry
@@:
endif
	.endif
	@mov eax,1
	ret
DllMain endp

	END DllMain

