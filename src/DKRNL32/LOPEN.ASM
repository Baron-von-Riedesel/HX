
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none

	include winbase.inc
	include macros.inc


HFILE_ERROR	equ -1
OF_READ 	equ  0
OF_WRITE	equ  1
OF_READWRITE equ  2

OF_SHARE_COMPAT 	= 0000H
OF_SHARE_EXCLUSIVE	= 0010H
OF_SHARE_DENY_WRITE = 0020H
OF_SHARE_DENY_READ	= 0030H
OF_SHARE_DENY_NONE	= 0040H

	.CODE

;*** flags: low nibble
;***        OF_READ oder OF_READWRITE oder OF_WRITE
;           high nibble
;***        OF_SHARE_COMPAT ...

_lopen proc public filename:dword,flags:dword

		mov eax,flags
		and al,03
		cmp al,OF_READ
		mov ecx,GENERIC_READ
		jz @F
		cmp al,OF_WRITE
		mov ecx,GENERIC_WRITE
		jz @F
		mov ecx,GENERIC_READ or GENERIC_WRITE
@@:
		mov eax,flags
		and al,70h
		xor edx,edx
		cmp al,OF_SHARE_EXCLUSIVE
		jz @F
		cmp al,OF_SHARE_COMPAT
		jz @F
		mov edx,FILE_SHARE_READ
		cmp al,OF_SHARE_DENY_WRITE
		jz @F
		mov edx,FILE_SHARE_WRITE
		cmp al,OF_SHARE_DENY_READ
		jz @F
		mov edx,FILE_SHARE_READ or FILE_SHARE_WRITE
@@:
		invoke CreateFileA,filename,\
					ecx,\
					edx,\
					0,\
					OPEN_EXISTING,\
					FILE_ATTRIBUTE_NORMAL,\
					0
		cmp eax,INVALID_HANDLE_VALUE
		jnz @F
		mov eax,HFILE_ERROR
@@:
		@strace <"_lopen(", filename, ", ", flags, ")=", eax>
		ret
_lopen endp

	END
