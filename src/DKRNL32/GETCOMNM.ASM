
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option casemap:none
	option proc:private

	include winbase.inc
	include macros.inc
	include dkrnl32.inc

	.CODE

GetComputerNameA proc public lpBuffer:ptr BYTE, pnSize:ptr DWORD

local	szName[16]:byte

	lea edx, szName
	mov ax,5e00h
	int 21h
	jc error

;--- the name is blank padded, remove blanks (size=15)
	mov byte ptr szName[15],0
	mov ecx, 15
	.while (ecx)
		.break .if (byte ptr [edx+ecx-1] != ' ')
		mov byte ptr [edx+ecx-1],0
		dec ecx
	.endw
	mov eax, pnSize
	.if (ecx < dword ptr [eax])
		mov [eax],ecx
		invoke lstrcpy, lpBuffer, edx
		jmp done
	.endif
	invoke SetLastError, ERROR_BUFFER_OVERFLOW
error:
	xor eax,eax
done:
	@strace <"GetComputerNameA(", lpBuffer, ", ", pnSize, ")=", eax>
	ret
	align 4

GetComputerNameA endp

GetComputerNameW proc public lpBuffer:ptr BYTE, pnSize:ptr DWORD

	mov ecx,pnSize
	mov edx,[ecx]
	sub esp,edx
	mov edx,esp
	invoke GetComputerNameA, edx, pnSize
	.if (eax)
		mov edx,esp
		mov ecx,pnSize
		mov ecx,[ecx]
		invoke ConvertAStrN, edx, lpBuffer, ecx
	.endif
	@strace <"GetComputerNameW(", lpBuffer, ", ", pnSize, ")=", eax>
	ret
	align 4
GetComputerNameW endp

	end

