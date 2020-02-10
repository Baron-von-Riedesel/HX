
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

_FormatMessage proto :dword, :ptr, :DWORD, :DWORD, :ptr BYTE, :DWORD, :ptr, :dword

FormatMessageW proc public dwFlags:DWORD , lpSource:ptr, dwMessageId:DWORD , dwLanguageId:DWORD, 
			lpBuffer:ptr WORD, nSize:DWORD , pArguments:ptr 

	@strace <"FormatMessageW(", dwFlags, ", ", lpSource, ", ", dwMessageId, ", ", dwLanguageId, ", ", lpBuffer, ", ", nSize, ", ", pArguments>
	test dwFlags, FORMAT_MESSAGE_FROM_STRING
	jz @F
	mov eax, lpSource
	call ConvertWStr
	mov lpSource, eax
@@:
	invoke _FormatMessage, dwFlags, lpSource, dwMessageId, dwLanguageId, lpBuffer, nSize, pArguments, 1
	.if (eax)
		pushad
		mov ebx, lpBuffer
		test dwFlags, FORMAT_MESSAGE_ALLOCATE_BUFFER
		jz userbuffer
		mov ecx, nSize	;this is the MINIMUM size only!
		cmp ecx, eax
		ja @F
		mov ecx, eax
		inc ecx			;cnt doesn't include the terminating 0
@@:
		shl ecx,1
		invoke LocalAlloc, LMEM_FIXED or LMEM_ZEROINIT, ecx
		and eax, eax
		jz error
		mov edi, eax
		mov eax, [esp+1Ch]	;restore EAX
		mov esi, [ebx]
		mov [ebx], edi
		mov edx, esi
		call copyback
		invoke LocalFree, edx
		jmp done
userbuffer:
		mov edi, ebx
		mov esi, ebx
		call copyback
done:
error:
		popad
	.endif
	@strace <"FormatMessageW()=", eax>
	ret
copyback:
	mov ecx, eax
	mov ah,0
	inc ecx			;copy the term 0 as well
	.while (ecx)
		dec ecx
		mov al,[esi+ecx]
		mov [edi+ecx*2],ax
	.endw
	retn
	align 4
FormatMessageW endp

	end

