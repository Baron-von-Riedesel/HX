
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

	.code

;--- convert wide stringN in EAX, size ECX

	public ConvertWStrN@0

;--- this function converts a wide asciiz string in EAX to an ascii string.
;--- the converted string is stored onto the stack and returned in EAX.
;--- if the calling function use the "uses" phrase, ESP has to be
;--- saved/restored on proc entry/exit

ConvertWStr proc public
	push eax
	invoke lstrlenW, eax
	inc eax
	mov ecx, eax
	pop eax
ConvertWStrN@0::
	pop edx
	sub esp,ecx
	sub esp,4
	and esp,not 3
	push edx
	push esi
	push edi
	lea edi, [esp+3*4]
	mov esi, eax
	jecxz done
@@:
	lodsw
	stosb
	dec ecx
	jnz @B
done:
	pop edi
	pop esi
	lea eax, [esp+4]
	ret
	align 4
ConvertWStr endp

;-- function to convert an AString back to a WString
;-- the destination pointer may be NULL!
;-- max size in cchMax

ConvertAStrN proc public uses esi edi eax pszAStr:ptr byte, pszWStr:ptr word, cchMax:dword
	mov esi, pszAStr
	mov edi, pszWStr
	and edi, edi
	jz exit
	mov ecx, cchMax
	xor eax,eax
	jecxz exit
nextchar:
	lodsb
	stosw
	and al,al
	loopnz nextchar
exit:
	ret
	align 4
ConvertAStrN endp

;--- convert a asciiz string to a wide string (same buffer)
;--- usually this is used to convert a returned string to a wide string
;--- size is in EAX, without terminating 0
;--- all registers preserved!

ConvertAStr proc public pBuffer:ptr
	pushad
	mov ecx, eax
	mov ah,0
	inc ecx			;copy the term 0 as well
	mov edi, pBuffer
	mov esi, edi
	.while (ecx)
		dec ecx
		mov al,[esi+ecx]
		mov [edi+ecx*2],ax
	.endw
	popad
	ret
	align 4
ConvertAStr endp

	end

