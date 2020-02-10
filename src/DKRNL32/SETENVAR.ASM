
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

	.CODE

SetEnvironmentVariableA proc public uses ebx esi edi pName:ptr BYTE, pValue:ptr BYTE

local	dwLength:DWORD
local	dwKeyLen:DWORD
local	dwPSP:DWORD
local	pTmpBlk:DWORD

ifdef _DEBUG
	mov ecx, pValue
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	@strace <"SetEnvironmentVariableA(", &pName, ", ", &ecx, ") enter">
endif

	invoke LocalAlloc, LMEM_FIXED, 8000h
	and eax, eax
	jz exit
	mov edi, eax
	mov pTmpBlk, eax

	mov ah,62h
	int 21h
	mov dwPSP, ebx
	push ds
	mov ds,ebx
	mov bx,ds:[002Ch]
	pop ds

	invoke lstrlen, pName
	mov dwKeyLen, eax

	push ds
	mov ds, ebx
	xor esi, esi
	.while (byte ptr [esi])
		mov ecx, dwKeyLen
		.if (byte ptr [esi+ecx] == '=')
			push esi
			push edi
			mov edi, pName
			repz cmpsb
			pop edi
			pop esi
			.if (ZERO?)
@@:
				lodsb
				and al, al
				jnz @B
				.continue
			.endif
		.endif
@@:
		lodsb
		stosb
		and al, al
		jnz @B
	.endw
	pop ds

	.if (pValue)
		push esi
		mov ecx, dwKeyLen
		mov esi, pName
		rep movsb
		mov al, '='
		stosb
		mov esi, pValue
@@:
		lodsb
		stosb
		and al, al
		jnz @B
		pop esi
	.endif

	push ds
	mov ds, ebx
	movsb
	lodsw
	.if (ax == 1)
		stosw
@@:
		lodsb
		stosb
		and al, al
		jnz @B
	.endif
	pop ds

	sub edi, pTmpBlk 
	mov dwLength, edi
	mov edx, ebx
	mov ebx, edi
	mov cl, bl
	shr ebx, 4
	test cl, 0Fh
	jz @F
	inc ebx
@@:
	mov esi, ebx		;save bx
	mov ax, 0102h		;try to realloc dos memory
	int 31h
	jnc @F
	@trace <"a new DOS memory block for environment must be allocated",13,10>
	mov ebx, esi		;failed, now try to alloc new DOS memory	
	mov ax, 0100h
	int 31h
	jc error

	push edx
	push ds
	mov ds,dwPSP
	xchg dx, ds:[002Ch]
	pop ds
;;	mov ax, 0101h		;do NOT free old environment block
;;	int 31h
	pop edx

@@:
	push es
	xor edi, edi
	mov es, edx
	mov esi, pTmpBlk
	mov ecx, dwLength
	rep movsb
	pop es
	@mov eax, 1
exit:
	push eax
	invoke LocalFree, pTmpBlk
	pop eax
	@strace <"SetEnvironmentVariableA()=", eax>
	ret
error:
	xor eax, eax
	jmp exit
	align 4
        
SetEnvironmentVariableA endp

SetEnvironmentVariableW proc public pName:ptr WORD, pValue:ptr WORD

	mov eax, pName
	invoke ConvertWStr
	mov pName, eax
	mov eax, pValue
	.if (eax)
		invoke ConvertWStr
	.endif
	invoke SetEnvironmentVariableA, pName, eax
	@strace <"SetEnvironmentVariableW(", pName, ", ", pValue, ")=", eax>
	xor eax,eax
	ret
	align 4

SetEnvironmentVariableW endp

	end
