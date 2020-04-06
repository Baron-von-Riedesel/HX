
;--- implements:
;--- GetFileAttributesA
;--- GetFileAttributesExA
;--- SetFileAttributesA

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

extern __CHECKOS:abs	;check if NT/W2K/XP (bug in LFN functions)

	.CODE

GetFileAttributesA proc public uses ebx pName:ptr byte

local	szFile[MAX_PATH]:byte

;--- if a path ends with a '\', skip it. unless it is "\" or "x:\"

	mov ebx, pName
	invoke lstrlen, ebx
	.if (eax && (byte ptr [ebx+eax-1] == '\'))
		cmp eax, 2
		jb dontstrip
		cmp byte ptr [ebx+eax-2],':'
		jz dontstrip
		push eax
		invoke lstrcpy, addr szFile, ebx
		pop eax
		lea ebx, szFile
		mov byte ptr [ebx+eax-1],0
	.endif
dontstrip:
	mov edx, ebx
	mov ax,7143h
	mov bl, 00			;file attributes
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ax,4300h
	int 21h
	jc error
success:
	mov eax, FILE_ATTRIBUTE_NORMAL
	and cx, 37h
	jz @F
	movzx eax,cx
@@:
done:
	@strace <"GetFileAttributesA(", &pName, ")=", eax>
	ret
error:
	movzx eax, ax
	invoke SetLastError,eax
	@mov eax, -1
	jmp done
	align 4

GetFileAttributesA endp

GetFileAttributesExA proc public uses ebx esi edi pName:ptr BYTE, fInfoLevelId:DWORD, lpFileInformation:ptr WIN32_FILE_ATTRIBUTE_DATA

local	hFileFind:DWORD
local	finddata:WIN32_FIND_DATAA


	invoke FindFirstFileA, pName, addr finddata
	cmp eax, INVALID_HANDLE_VALUE
	jz error
	mov ebx, eax
	mov edi, lpFileInformation
	lea esi, finddata
	mov ecx, sizeof WIN32_FILE_ATTRIBUTE_DATA / 4
	rep movsd
	invoke FindClose, ebx
done:
	@mov eax, 1
exit:
	@strace <"GetFileAttributesExA(", &pName, ", ", fInfoLevelId, ")=", eax>
	ret
error:
	xor eax, eax
	jmp exit
	align 4

GetFileAttributesExA endp

;--- with SetFileAttributes one may also set attributes of a directory
;--- but for this to work one must reset the directory attribute
;--- 01:read-only
;--- 02:hidden
;--- 04:system
;--- 08:volume label
;--- 10:directory
;--- 20:archive

SetFileAttributesA proc public uses ebx pName:ptr BYTE, attribs:dword

	mov edx,pName
	mov ecx,attribs
;;	and cx, 37h
	and cx, 27h		;reset directory attribute as well
	mov bl,01
	mov ax,7143h
	stc
	int 21h
	jnc success
	cmp ax,7100h
	jnz error
	mov ax,4301h
	int 21h
	jnc success
error:
	movzx eax,ax
	invoke SetLastError,eax
	xor eax,eax
success:
	@strace <"SetFileAttributesA(", &pName, ", ", attribs, ")=", eax>
	ret
	align 4
SetFileAttributesA endp

	end
