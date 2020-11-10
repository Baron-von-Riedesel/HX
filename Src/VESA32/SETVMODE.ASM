
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include function.inc
	include vesa32.inc
	include isvbop.inc
	include equates.inc
	include macros.inc

?SETDACWIDTH	equ 1

if ?VESAVDD
externdef g_hVesaVDD:dword
endif

	.CODE

SetVesaMode proc public uses ebx grmode:dword

	mov ebx,grmode
	mov ax,4f02h				  ;set vesa mode
if ?VESAVDD
	.if (g_hVesaVDD)
		push eax
		mov eax, g_hVesaVDD
		DispatchCall
		pop eax
	.else
		int 10h
	.endif
else
	int 10h
endif
	cmp ax,004Fh
	jnz error
switchok:
if ?SETDACWIDTH
	test byte ptr g_vesainfo.Capabilities, VESACAP_DAC8
	jz @F
	cmp byte ptr grmode+1,0
	jz @F
	mov bx,0800h		;set DAC width to 8 bits
	mov ax,4F08h
	int 10h
@@:
endif
exit:
	@strace <"SetVesaMode(", grmode, ")=", eax>
	ret
error:
	mov eax, grmode
	and ah,ah
	jnz @F
	int 10h
	jmp	switchok
@@:
	xor eax,eax
	jmp exit
	align 4
SetVesaMode endp

GetVesaMode proc public uses ebx

	mov ax,4f03h				  ;get vesa mode
	int 10h
	cmp ax,004Fh
	jnz error
	movzx eax,bx
exit:
	@strace <"GetVesaMode()=", eax>
	ret
error:
	xor eax,eax
	jmp exit
	align 4

GetVesaMode endp

	end

