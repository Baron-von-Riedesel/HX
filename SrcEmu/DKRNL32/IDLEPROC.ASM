
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

?USEDOSIDLE		equ 0		;problems in WinXP?

	include winbase.inc
	include dkrnl32.inc
	include dpmi.inc

	.DATA

g_dwIdleProc		dd offset _GiveupTimeSlice
g_bDispatchFlags	db 0

	.CODE

?RMIDLE equ 1

_GiveupTimeSlice proc public

if ?RMIDLE         ;call int 2Fh,ax=1680h via int 31h, ax=0300h
	pushad
	push es
	sub esp,34h     ;sizeof RMCS is 32h only, ensure stack is dword aligned!
	@loadesp ebp
	mov edi, ebp
	xor ecx, ecx
	mov [ebp].RMCS.rSSSP, ecx
	mov [ebp].RMCS.rFlags, 202h
	mov word ptr [ebp].RMCS.rEAX, 1680h
	mov bx, 2Fh
	mov ax, 300h
	push ss
	pop es
	int 31h
	cmp byte ptr [ebp].RMCS.rEAX, 80h
	jnz done
else
	mov ax, 1680h
	int 2Fh
	cmp al, 80h
	jnz done
endif
if ?USEDOSIDLE
 ife ?RMIDLE
    push es
	push edi
	push ecx
	sub esp, 34h
	@loadesp edi
	xor ecx, ecx
	push ss
	pop es
	mov es:[edi].RMCS.rSSSP, ecx
	mov es:[edi].RMCS.rFlags, 202h
 endif
	mov bx, 28h
	mov ax, 300h
	int 31h
 ife ?RMIDLE
	add esp, 34h
	pop ecx
	pop edi
	pop es
 endif
else
	cmp cs:[g_bHost], HF_WINNT
	jnz @F
	mov ah,01h
	int 16h
@@:
endif
done:
if ?RMIDLE
	add esp, 34h
	pop es
	popad
endif
	ret
_GiveupTimeSlice endp

	end
