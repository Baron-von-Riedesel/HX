
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
	include dkrnl32.inc

	.CODE

LockFile proc public uses ebx esi edi handle:dword,
				dwFileOffsLow:dword,
				dwFileOffsHigh:dword,
				dwNumBytesLow:dword,
				dwNumBytesHigh:dword

	mov dx,word ptr dwFileOffsLow+0
	mov cx,word ptr dwFileOffsLow+2
	mov di,word ptr dwNumBytesLow+0
	mov si,word ptr dwNumBytesLow+2
	mov ebx,handle
	mov ax,5C00h
	int 21h
	jc error
	@mov eax,1
exit:
	@strace <"LockFile(", handle, ", ", dwFileOffsLow, ", ", dwFileOffsHigh, ", ", dwNumBytesLow, ", ", dwNumBytesHigh, ")=", eax>
	ret
error:
	movzx eax,ax
	invoke SetLastError,eax
	xor eax,eax
	jmp exit
	align 4

LockFile endp

UnlockFile proc public uses ebx esi edi handle:dword,
				dwFileOffsLow:dword,
				dwFileOffsHigh:dword,
				dwNumBytesLow:dword,
				dwNumBytesHigh:dword

	mov dx,word ptr dwFileOffsLow+0
	mov cx,word ptr dwFileOffsLow+2
	mov di,word ptr dwNumBytesLow+0
	mov si,word ptr dwNumBytesLow+2
	mov ebx,handle
	mov ax,5C01h
	int 21h
	jc error
	@mov eax,1
exit:
	@strace <"UnlockFile(", handle, ", ", dwFileOffsLow, ", ", dwFileOffsHigh, ", ", dwNumBytesLow, ", ", dwNumBytesHigh, ")=", eax>
	ret
error:
	movzx eax,ax
	invoke SetLastError,eax
	xor eax,eax
	jmp exit
	align 4

UnlockFile endp

	end

