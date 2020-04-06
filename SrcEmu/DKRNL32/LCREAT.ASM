
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc


HFILE_ERROR  equ -1
OF_READ 	 equ  0
OF_WRITE	 equ  1
OF_READWRITE equ  2

OF_SHARE_COMPAT 	= 0000H
OF_SHARE_EXCLUSIVE	= 0010H
OF_SHARE_DENY_WRITE = 0020H
OF_SHARE_DENY_READ	= 0030H
OF_SHARE_DENY_NONE	= 0040H

	.CODE

;*** attrib:0 normal
;***        1 read only
;***        2 hidden
;***        4 system

;--- using CreateFile directly will save you some instruction cycles


_lcreat proc public uses ebx filename:dword,attrib:dword

	xor edx,edx
	mov eax,attrib
	test al,1
	jz @F
	or edx,FILE_ATTRIBUTE_READONLY
@@:
	test al,2
	jz @F
	or edx,FILE_ATTRIBUTE_HIDDEN
@@:
	test al,4
	jz @F
	or edx,FILE_ATTRIBUTE_SYSTEM
@@:
	and edx,edx
	jnz @F
	mov edx,FILE_ATTRIBUTE_NORMAL
@@:
	mov ecx,CREATE_NEW
	mov ebx,GENERIC_WRITE
@@:
	push edx
	push ecx
	invoke CreateFileA,filename,\
				ebx,\
				FILE_SHARE_READ or FILE_SHARE_WRITE,\
				0,\
				ecx,\
				edx,\
				0
	pop ecx
	pop edx
	cmp eax,INVALID_HANDLE_VALUE
	jnz @F
	or ebx,GENERIC_READ
	mov eax,TRUNCATE_EXISTING
	cmp ecx,eax
	mov ecx,eax
	jnz @B
	mov eax,HFILE_ERROR
@@:
	@strace <"_lcreat(", filename, ", ", attrib, ")=", eax>
	ret
	align 4

_lcreat endp

	END
