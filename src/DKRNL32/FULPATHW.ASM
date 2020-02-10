
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

;--- fname: inp
;--- pBuffer:out
;--- pFilename: out

GetFullPathNameW proc public fname:ptr WORD,bufSize:dword,pBuffer:ptr WORD,pFilename:ptr ptr WORD

local	tmpBuffer[MAX_PATH]:byte

	@strace <"GetFullPathNameW(", fname, ", ", bufSize, ", ", pBuffer, ", ", pFilename, ") enter">
	mov eax,fname
	call ConvertWStr
	lea ecx, tmpBuffer
	invoke GetFullPathNameA, eax, bufSize, ecx, pFilename
	.if (eax)
		pushad
		mov ecx, eax		;size without terminating 0
		inc ecx
		cmp ecx, bufSize
		jb @F
		mov ecx, bufSize
@@:
		mov edi, pBuffer
		lea esi, tmpBuffer
		mov edx, pFilename
		and edx, edx
		jz @F
		mov eax, [edx]
		sub eax, esi
		shl eax, 1
		add eax, edi
		mov [edx], eax
@@:
		jecxz done
		mov ah,0
@@:
		lodsb
		stosw
		loop @B
done:
		popad
	.endif
	@strace <"GetFullPathNameW()=", eax>
	ret

GetFullPathNameW endp

	end

