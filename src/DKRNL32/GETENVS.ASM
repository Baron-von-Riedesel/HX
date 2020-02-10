
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include macros.inc

?CURDIR equ 0

	.CODE

GetEnvironmentStrings proc public
GetEnvironmentStrings endp

GetEnvironmentStringsA proc public uses ebx edi esi

if ?CURDIR
local	szCurrDir[MAX_PATH]:byte
endif

if ?CURDIR
	invoke GetCurrentDirectory, sizeof szCurrDir, addr szCurrDir
	add eax,5
	mov esi, eax
endif
	mov ah,62h
	int 21h
	push ds
	mov ds,ebx
	mov bx,ds:[002Ch]
	pop ds
	xor eax,eax
	and bx, bx
	jz done

	push es
	mov es,ebx
	xor edi,edi
	mov ecx,-1
	mov al,00
@@:
	repnz scasb
	scasb
	jnz @B
	inc edi
	inc edi			;skip "0001" word	
	repnz scasb
	dec edi			;line inserted 22.8.2003
	pop es
if ?CURDIR
	add edi, esi
endif
	invoke LocalAlloc, LMEM_FIXED, edi
	and eax,eax
	jz done
	mov ecx,edi		;edi is size
	mov edi,eax
if ?CURDIR
	push eax
	mov al,'='
	stosb
	mov ax,word ptr szCurrDir
	stosw
	mov al,'='
	stosb
	lea esi, szCurrDir
@@:
	lodsb
	stosb
	and al,al
	loopnz @b
	pop eax
endif
	push ds
	mov ds,ebx
	xor esi,esi
	rep movsb
	pop ds
done:
	@strace <"GetEnvironmentStringsA()=", eax>
	ret
	align 4

GetEnvironmentStringsA endp


FreeEnvironmentStringsA proc public pStrings:dword
	@strace <"FreeEnvironmentStringsA(", pStrings, ")">
	invoke LocalFree, pStrings
	ret
	align 4
FreeEnvironmentStringsA endp

	end

