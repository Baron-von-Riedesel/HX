
;--- implements GetEnvironmentVariableA()

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


@swapdses macro
ife ?FLAT
	mov eax, es
	push ds
	mov ds, eax
	pop es
endif
	endm

PUSHADS struct
rEdi	dd ?
rEsi	dd ?
rEbp	dd ?
		dd ?
rEbx	dd ?
rEdx	dd ?
rEcx	dd ?
rEax	dd ?
PUSHADS ends

	.CODE

;--- maxsize may be NULL!

GetEnvironmentVariableA proc public uses esi edi ebx key:ptr BYTE, buffer:ptr BYTE, maxsize:dword

local	keysize:dword
local	pEnv:dword

	invoke lstrlen, key
	mov keysize, eax

	mov ah, 62h
	int 21h
	push ds
	mov ds, ebx
	mov bx, ds:[2ch]
	pop ds
	mov ax, 6
	int 31h

ife ?FLAT
	push es
	push gs
	pop es
@flat equ <es>
else
@flat equ <ds>
endif
	jc error		;C if environment is NULL

	push cx
	push dx
	pop edi

	.while (byte ptr @flat:[edi])
		mov esi,key
		mov ecx,keysize
		mov edx, edi
		repz cmpsb
		.if (ZERO? && byte ptr @flat:[edi] == '=')
			inc edi
			mov esi,edi
			or ecx,-1
			mov al,0
			repnz scasb
			sub edi, esi
			mov eax, edi
			cmp eax, maxsize
			ja done
			push eax
			mov edi,buffer
			mov ecx,eax
			@swapdses
			rep movsb
			@swapdses
			pop eax
			dec eax
			jmp done
		.endif
		mov edi, edx
		mov al, 0
		or ecx, -1
		repnz scasb
	.endw
error:
	xor eax, eax
done:
ife ?FLAT
	pop es
endif
ifdef _DEBUG
	.if (eax && buffer && (eax < maxsize))
		@strace <"GetEnvironmentVariableA(", &key, ", ", buffer, ", ", maxsize, ")=", eax, " [", &buffer, "]">
	.else
		@strace <"GetEnvironmentVariableA(", &key, ", ", buffer, ", ", maxsize, ")=", eax>
	.endif
endif
	ret
	align 4

GetEnvironmentVariableA endp

;--- this is an internal function

_GetEnvironmentVariableInt proc public uses esi ebx pszName:ptr BYTE

	sub esp, 128
	@loadesp esi
	invoke GetEnvironmentVariable, pszName, esi, 128
	.if (eax)
		mov ecx, eax
		xor edx, edx
		mov bl,0
		.if ((ecx >= 2) && (word ptr [esi] == "x0"))
			lodsw
			dec ecx
			dec ecx
			inc bl
		.endif
		.while (ecx)
			lodsb
			sub al,'0'
			movzx eax,al
			.if (bl)
				shl edx,4
			.else
				add edx, edx
				lea edx,[edx+edx*4]
			.endif
			add edx, eax
			dec ecx
		.endw
		mov eax, edx
	.endif
	add esp,128
	ret
	align 4

_GetEnvironmentVariableInt endp

	end
