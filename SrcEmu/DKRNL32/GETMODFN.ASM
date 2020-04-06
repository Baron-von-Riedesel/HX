
;--- implements GetModuleFileNameA()

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

ife ?FLAT
_GetModuleFileName proto stdcall :dword, :dword, :dword
endif

	.CODE

GetModuleFileNameA proc public uses esi edi handle:dword,pBuffer:ptr byte,lBuffer:dword

if ?FLAT

	test [g_bIntFl],IKF_PELDR
	jnz useldr
	push ebx
	mov ah,51h
	int 21h
	mov es,ebx
	pop ebx
	mov es,es:[002Ch]
	mov ecx,-1
	xor eax,eax
	xor edi,edi
	cld
@@:
	repnz scasb			;get to end of environment
	scasb				;search for 00 00
	jnz @B				;else scan next string
	mov eax,ds			;swap(ds,es)
	push es
	pop ds
	mov es,eax
	lea esi,[edi+2]
	jmp copy
useldr:        
;--- use dpmild32 to get pointer to module name

	mov edx,handle
	mov ax,4B86h
	int 21h
	.if (eax)
		mov esi, eax
copy:
		mov edi, pBuffer
		mov ecx, lBuffer
@@:
		lodsb
		stosb
		and al,al
		loopnz @B
		push es
		pop ds
		mov eax,lBuffer
		sub eax,ecx
		dec eax
	.endif
else
        invoke _GetModuleFileName,handle,pBuffer,lBuffer
endif
exit:
	@strace <"GetModuleFileNameA(", handle, ", ", pBuffer, ", ", lBuffer, ")=", eax, " [", &pBuffer, "]">
	ret
	align 4
GetModuleFileNameA endp

	end

