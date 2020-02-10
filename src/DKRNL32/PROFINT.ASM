
;--- GetPrivateProfileIntA

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

	.CODE

String2Number proc public uses esi ebx pStr:ptr BYTE,pDW:ptr dword,radix:dword

	mov ecx,radix
	xor edx,edx
	mov esi,pStr
	mov bl,0
next:
	lodsb
	and al,al
	jz  exit
	cmp al,' '
	jz  exit
if 1
	cmp al,','
	jz  exit
endif
	sub al,'0'
	jc  errexit
	cmp al,9
	jbe @F
	cmp cl,16
	jc  errexit
	or  al,20h
	sub al,27h
	jc  errexit
	cmp al,10h
	cmc
	jc  errexit
@@:
	movzx eax,al
	push eax
	mov eax,edx
	mul ecx
	pop edx
	add edx,eax
	inc bl
	jmp next
exit:
	cmp bl,1	;C if 0 (error)		 
	jc	errexit
	mov eax,pDW
	mov [eax],edx
	lea eax,[esi-1]
	ret
errexit:
	xor eax,eax
	ret
	align 4
String2Number endp

GetPrivateProfileIntA proc public lpAppName:ptr byte,
        lpKeyName:ptr byte, nDefault:DWORD, lpFilename:ptr byte

local	szText[128]:byte
local	rc:dword

	invoke GetPrivateProfileStringA, lpAppName, lpKeyName, CStr(""),\
		addr szText, sizeof szText, lpFilename
	.if (eax)
		invoke String2Number, addr szText, addr rc, 10
		.if (eax)
			mov eax, rc
		.else
			mov eax, nDefault
		.endif
	.else
		mov eax, nDefault
	.endif
ifdef _DEBUG
	mov ecx, lpAppName
	.if (!ecx)
		mov ecx, CStr("NULL")
	.endif
	mov edx, lpKeyName
	.if (!edx)
		mov edx, CStr("NULL")
	.endif
	@strace <"GetPrivateProfileIntA(", ecx, ", ", edx, ", ", nDefault, ", ", lpFilename, ")=", eax>
endif
	ret
	align 4

GetPrivateProfileIntA endp

	end

