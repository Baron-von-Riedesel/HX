
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

extern	__CHECKOS:abs

	.CODE

MAXPATH equ 260

GetCurrentDirectoryA proc public uses ebx esi edi maxlen:dword,buffer:ptr byte

local   tmpbuf[MAXPATH]:byte

;*** the buffer may be very small. In this
;*** case, GetCurrentDirectory returns the requested size of the buffer

	mov ah,19h			   ;get drive
	int 21h
	mov dl,al
	inc dl
	add al,'A'
	lea edi,tmpbuf		   ;store it in tmpbuf
	mov ah,':'
	stosw
	mov al,'\'
	stosb

	mov esi,edi
	mov ax,7147h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ah,47h
	int 21h
	jc error
success:
	mov al,00
	mov ecx,-1
	repnz scasb
	mov eax,edi
	lea ecx,tmpbuf
	sub eax,ecx 		;required size of buffer
	cmp eax,maxlen
	ja exit				;buffer too small, return req. size
	mov ecx,eax
	lea esi,tmpbuf
	mov edi,buffer
	rep movsb
	dec eax 			;do not count last '00'
	jmp exit
error:
	movzx eax, al
	invoke SetLastError, eax
	xor eax,eax
exit:
	@strace <"GetCurrentDirectoryA(", maxlen, ", ", buffer, ")=", eax>
	ret
	align 4

GetCurrentDirectoryA endp

GetCurrentDirectoryW proc public maxlen:dword,buffer:ptr WORD
	sub esp, maxlen
	invoke GetCurrentDirectoryA, maxlen, esp
	.if (eax)
		mov edx, esp
		invoke ConvertAStrN, edx, buffer, maxlen
	.endif
	add esp, maxlen
	@strace <"GetCurrentDirectoryW(", maxlen, ", ", buffer, ")=", eax>
	ret
	align 4
GetCurrentDirectoryW endp

	end

