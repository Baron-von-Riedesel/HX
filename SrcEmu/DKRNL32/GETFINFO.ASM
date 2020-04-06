
	.386
if ?FLAT
	.MODEL FLAT, stdcall
else
	.MODEL SMALL, stdcall
endif
	option proc:private
	option casemap:none

	include winbase.inc
	include dkrnl32.inc
	include macros.inc

?FILEATTR equ 1					;get file attributes without int 21h, ax=71A6h

extern	__CHECKOS:abs			;check if NT/W2K/XP (bug in LFN functions)

	.CODE

GetFileInformationByHandle proc public uses ebx esi edi handle:dword,pFileInfo:ptr BY_HANDLE_FILE_INFORMATION

local   hw:dword

	mov ebx, handle
	mov edx, pFileInfo
	mov ax,71A6h		;this is NOT implemented in DOSLFN!!!
	stc
	int 21h
	jnc exit
	cmp ax,7100h
	jnz error

	mov edi, edx
	mov ax, 5700h	;get last write date/time
	int 21h
	jc error
	xor eax,eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftLastWriteTime, eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftLastAccessTime, eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftCreationTime, eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftLastWriteTime+4, eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftLastAccessTime+4, eax
	mov dword ptr [edi].BY_HANDLE_FILE_INFORMATION.ftCreationTime+4, eax
	invoke _DosDateTimeToFileTime, edx, ecx, addr [edi].BY_HANDLE_FILE_INFORMATION.ftLastWriteTime
	mov ax, 5704h	;get last access date/time (time always 0)
	int 21h
	.if (!CARRY?)
		invoke _DosDateTimeToFileTime, edx, ecx, addr [edi].BY_HANDLE_FILE_INFORMATION.ftLastAccessTime
	.endif
	mov ax, 5706h	;get creation date/time (modifies SI!)
	int 21h
	.if (!CARRY?)
		invoke	_DosDateTimeToFileTime, edx, ecx, addr [edi].BY_HANDLE_FILE_INFORMATION.ftCreationTime
	.endif

ife ?FILEATTR
	mov [edi].BY_HANDLE_FILE_INFORMATION.dwAttributes, FILE_ATTRIBUTE_NORMAL
else
	call GetAttrByHandle
	mov [edi].BY_HANDLE_FILE_INFORMATION.dwAttributes, eax
endif

	mov [edi].BY_HANDLE_FILE_INFORMATION.nLinks,1
	invoke GetFileSize, ebx, addr [edi].BY_HANDLE_FILE_INFORMATION.dwFileSizeHigh
	mov [edi].BY_HANDLE_FILE_INFORMATION.dwFileSizeLow,eax
	inc eax
exit:
	@strace	<"GetFileInformationByHandle(", handle, ", ", pFileInfo, ")=", eax>
	ret
error:
	movzx	eax,ax
	invoke	SetLastError, eax
	xor		eax,eax
	jmp		exit
	align 4

GetFileInformationByHandle endp

if ?FILEATTR

;--- get file attributes by handle
;--- this relies upon "undocumented" DOS structures (SFT)
;--- size of SFT entry is either 35h (DOS 3) or 3Bh (DOS 4+)

GetAttrByHandle proc uses ebx esi

	mov esi, ebx
	mov ah,51h
	int 21h
	push es
	mov es,ebx
	movzx ecx,word ptr es:[32h]
	cmp esi, ecx
	jnc error1
	movzx ebx,word ptr es:[34h]
	movzx eax,word ptr es:[36h]
	shl eax,4
	add ebx, eax
	movzx eax, byte ptr [ebx+esi]	;get index into SFT
	cmp al,-1
	jz error1
	mov esi, eax
	mov ah,52h
	int 21h
	movzx eax,word ptr es:[ebx+4]	;get first SFT
	movzx ebx,word ptr es:[ebx+6]
	cmp ax,-1
	jz error1
	pop es
	shl ebx, 4
	add ebx, eax
nexttable:
	movzx ecx, word ptr @flat:[ebx+4]
	cmp esi, ecx
	jc found
	movzx edx, word ptr @flat:[ebx+0]
	cmp dx,-1
	jz error2
	movzx ebx, word ptr @flat:[ebx+2]
	shl ebx,4
	add ebx, edx
	sub esi, ecx
	jmp nexttable
found:
	add ebx, 4+2	;skip pointer to next table and entries count
	push ebx
	mov ax,3000h
	int 21h
	pop ebx
	cmp ax, 0003	;DOS 3.0 has no attributes in table
	jz error2
	mov ecx, 35h	;size of entry for dos 3.1-3.3
	cmp al,4
	jc @F
	mov cl,3Bh		;size for dos 4-7
@@:
	mov eax, esi
	mul ecx
	movzx eax, byte ptr @flat:[ebx+eax+4]
	and al,al
	jz error2
	ret
error1:
	pop es
error2:
	mov eax,FILE_ATTRIBUTE_NORMAL
	ret
	align 4

GetAttrByHandle endp

endif

end

