
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

extern	__CHECKOS:abs			;check if NT/W2K/XP (bug in LFN functions)

	.CODE

;--- this function should also work with special files!

GetFileSize proc public uses ebx esi handle:dword,pHighWord:ptr dword

local	bhfi:BY_HANDLE_FILE_INFORMATION
local	dwHigh:dword
local	oldpos:dword

	mov ebx, handle
	cmp ebx, 10000h
	ja isspecial
	lea edx, bhfi
	mov ax,71A6h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
;------------------------------------- get current pos in dwHigh::EAX
	xor ecx,ecx
	mov dwHigh, ecx 	   
	invoke SetFilePointer, ebx, ecx, addr dwHigh, FILE_CURRENT 
	cmp eax,-1
	jz exit
	mov esi, eax
	xor eax, eax
	mov ecx, pHighWord
	jecxz @F
	mov [ecx], eax
@@:
	invoke SetFilePointer, ebx, eax, ecx, FILE_END
	push eax
;------------------------------------- restore current pos
	invoke SetFilePointer, ebx, esi, addr dwHigh, FILE_BEGIN
	pop eax
	jmp exit
error:
	movzx eax,ax
	invoke SetLastError, eax
	mov eax,-1
	jmp exit
success:

;--- lasterror should be set to zero if pHighWord is != 0

	mov eax,bhfi.dwFileSizeLow
	mov ecx,pHighWord
	jecxz exit
	mov edx,bhfi.dwFileSizeHigh
	mov [ecx],edx
exit:
	@strace <"GetFileSize(", ebx, ", ", pHighWord, ")=", eax>
	ret
isspecial:
	mov ax,5
	jmp error
	align 4
GetFileSize endp

GetFileSizeEx proc public handle:dword, pSize:ptr qword

	mov ecx, pSize
	add ecx, 4
	invoke GetFileSize, handle, ecx
	inc eax
	jz @F
	dec eax
	mov ecx, pSize
	mov [ecx],eax
	@mov eax,1
@@:
	@strace <"GetFileSizeEx(", handle, ", ", pSize, ")=", eax>
	ret
	align 4
GetFileSizeEx endp

	end
