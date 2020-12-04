
;--- implements IIDFromString, CLSIDFromString
;--- StringFromGUID2
;--- CLSIDFromProgID, ProgIDFromCLSID

	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include winuser.inc
	include macros.inc

	.CODE

gethex proc
	xor edx, edx
	xor eax, eax
nextitem:
	lodsw
	cmp ah,0
	jnz error
	or al,20h
	sub al,'0'
	jc error
	cmp al,9
	jbe @F
	sub al,27h
	jc error
	cmp al,10h
	jnc error
@@: 
	shr edx,4
	add edx, eax
	loop nextitem
	mov eax, edx
	clc
	ret
error:
	stc
	ret
	align 4
gethex endp

IIDFromString proc public uses esi edi lpOleStr:ptr WORD, pIID:ptr BYTE
IIDFromString endp

CLSIDFromString proc public uses esi edi ebx lpOleStr:ptr WORD, pClsid:ptr BYTE

	mov esi,lpOleStr
	mov edi, pClsid

	lodsw
	cmp ax,'{'
	jnz error
	mov ecx, 8
	call gethex
	jc error
	stosd
	mov bl,2
@@:
	lodsw
	cmp ax,'-'
	jnz error
	mov ecx, 4
	call gethex
	jc error
	stosw
	dec bl
	jnz @B

	lodsw
	cmp ax,'-'
	jnz error

	mov bl,2
@@:
	mov ecx, 2
	call gethex
	jc error
	stosb
	dec bl
	jnz @B

	lodsw 
	cmp ax,'-'
	jnz error

	mov bl,6
@@:
	mov ecx, 2
	call gethex
	jc error
	stosb
	dec bl
	jnz @B

	lodsw
	cmp ax,'}'
	jnz error
	mov eax,S_OK
exit:
	@strace <"CLSIDFromString(", lpOleStr, ", ", pClsid, ")=", eax>
	ret
error:
	mov eax,CO_E_CLASSSTRING
	jmp exit
	align 4

CLSIDFromString endp

StringFromGUID2 proc public pClsid:ptr BYTE, lpszwStr:ptr WORD, cbMax:DWORD

local	szTemp[40]:byte

	mov edx, pClsid
	mov ecx, 8
	xor eax, eax
	.repeat
		dec cl
		mov al, [edx+ecx+8]
		push eax
	.until (cl == 0)
	mov cl, 2
	.repeat
		dec cl
		mov ax, [edx+ecx*2+4]
		push eax
	.until (cl == 0)
	push dword ptr [edx+0]
	invoke wvsprintf, addr szTemp, CStr("{%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X}"), esp
	add esp, 11*4
	invoke MultiByteToWideChar, CP_ACP, MB_PRECOMPOSED, addr szTemp, -1, lpszwStr, cbMax
;	mov eax,S_OK
	@strace <"StringFromGUID2(", pClsid, ", ", lpszwStr, ", ", cbMax, ")=", eax>
	ret
	align 4

StringFromGUID2 endp

CLSIDFromProgID proc public lpszwProgID:ptr WORD, pClsid:ptr BYTE

	mov eax,CO_E_CLASSSTRING
	@strace <"CLSIDFromProgID(", lpszwProgID, ", ", pClsid, ")=", eax, " *** unsupp ***">
	ret
	align 4

CLSIDFromProgID endp

ProgIDFromCLSID proc public pClsid:ptr BYTE, lpszwProgID:ptr WORD

	mov eax,REGDB_E_CLASSNOTREG
	@strace <"ProgIDFromCLSID(", pClsid, ", ", lpszwProgID, ")=", eax, " *** unsupp ***">
	ret
	align 4

ProgIDFromCLSID endp

	end
