
;--- implements Win32 GetPrivateProfileStringA emulation
;--- size is limited to ?BUFSIZE

	.386
if ?FLAT
	.MODEL FLAT
@flat equ <ds>
else
	.MODEL SMALL
@flat equ <gs>
endif
	option proc:private
	option casemap:none

HFILE_ERROR equ -1
?BUFSIZE	equ 4000h	;max size of config file

	.nolist
	include function.inc
	include dpmi.inc
	include macros.inc
	.list

@DosCall macro
	int 21h
endm

@flatprefix macro
ife ?FLAT
	db 65h	;is GS prefix
endif
endm

@flatstosb macro
if ?FLAT
	stosb
else
	mov @flat:[edi],al
	inc edi
endif
endm

@flatstosw macro
if ?FLAT
	stosw
else
	mov @flat:[edi],ax
	inc edi
	inc edi
endif
endm

@flatlodsb macro
	@flatprefix
	lodsb
endm

@movsb2flat macro
if ?FLAT
	movsb
else
	mov al,[esi]
	inc esi
	@flatstosb
endif
endm

@set2flat macro reg
ife ?FLAT
	push reg
	push @flat
	pop reg
endif
endm

@restore macro reg
ife ?FLAT
	pop reg
endif
endm

	.CODE

ToLower proc
	cmp al,'A'
	jc @F
	cmp al,'Z'
	ja @F
	or al,20h
@@:
	ret
ToLower endp

;--- check if 2 strings are equal
;--- edi points to flat memory
;--- edi points to string

check proc uses esi

check_0:
	mov al,@flat:[edi]
	call ToLower
	mov ah,al
	mov al,[esi]
	call ToLower
	inc esi
	inc edi
	cmp al,ah
	jz check_0
	dec esi
	dec edi
	mov al,[esi]
	ret
check endp

skipline proc
nextchar:
	mov al, @flat:[edi]
	cmp al, 10
	jz done
	cmp al, 0
	jz doneall
	inc edi
	jmp nextchar
done:
	inc edi
doneall:
	ret
skipline endp

skipline2 proc
if 0
	.while (byte ptr @flat:[esi])
		@flatlodsb
		.break .if (al == 10)
	.endw
else
@@:
	cmp byte ptr @flat:[esi],0
	jz @F
	@flatlodsb
	cmp al,10
	jnz @B
@@:
endif
	ret
skipline2 endp

copykeyname proc

	dec esi
	mov ebx, ecx
	mov edx, edi
next:
	@flatlodsb
	cmp al,'='
	jz iskey
	cmp al,13
	jz done
	cmp al, 0
	jz done2
	stosb
	dec ecx
	jnz next
done2:
	dec esi
done:
	mov edi, edx
	mov ecx, ebx
	jmp exit
iskey:
	mov al,0
	stosb
	dec ecx
exit:
	ret
copykeyname endp

;--- copy all keys in a section to edi, max size ecx
;--- end is indicated by 2 00 bytes
;--- esi = flat
;--- edi = std

getallkeys proc
	jecxz done
	dec ecx
	.while (ecx && byte ptr @flat:[esi])
		@flatlodsb
		cmp al,';'
		jz skip
		cmp al,13
		jz skip
		call copykeyname
skip:
		call skipline2
	.endw
	mov al,0
	stosb
done:
	ret
getallkeys endp

;--- esi = flat

copysectionname proc
next:
	@flatlodsb
	cmp al,']'
	jz done
	cmp al,13
	jz done
	cmp al, 0
	jz done2
	stosb
	dec ecx
	jnz next
	dec edi
	inc ecx
	jmp done
done2:
	dec esi
done:
	mov al,0
	stosb
	dec ecx
	ret
copysectionname endp

;--- copy all section names to edi, max size ecx
;--- end is indicated by 2 00 bytes

getallsections proc

	jecxz done
	dec ecx
	.while (ecx && byte ptr @flat:[esi])
		@flatlodsb
		.if (al == '[')
			call copysectionname
		.endif
		call skipline2
	.endw
	mov al,0
	stosb
done:
	ret
getallsections endp

;--- section -> esi
;--- file -> edi

searchsection proc

	mov ecx, -1
	.while (byte ptr @flat:[edi])
		.if (byte ptr @flat:[edi] == '[')
			inc edi
			call check
			cmp ah,']'
			jz done
		.endif
		call skipline
	.endw
error:
	stc
	ret
done:
	clc
	ret

searchsection endp

;--- esi -> entry
;--- edi -> file

searchentry proc

	mov ecx, -1
	.while (byte ptr @flat:[edi])
		.break .if (byte ptr @flat:[edi] == '[')
		call	check
		cmp 	ah,'='
		jz		done
		call skipline
	.endw
error:
	stc
	ret
done:
	ret
searchentry endp


GetPrivateProfileStringA proc stdcall public uses esi edi ebx lpAppName:ptr byte,
		lpKeyName:ptr byte, lpDefault:ptr byte, retbuff:ptr byte, bufsize:dword, filename:ptr byte

local	rc:dword
local	pMem:dword
local	dwMem:dword

ife ?FLAT
	movzx ebp,bp	;clear hiword ebp if we're running on a 16-bit stack
endif
	xor eax,eax
	mov rc,eax
	mov pMem, eax
	mov ebx,?BUFSIZE/10h
	mov ah,48h
	@DosCall
	jc copydefault
	mov pMem, eax
	mov edx,filename
	mov ax,3d20h
	@DosCall
	mov ebx,-1
	jc copydefault
	mov ebx,eax
	mov ecx,?BUFSIZE-1
	push ds
	mov ds,pMem
	xor edx,edx
	mov ah,3Fh
	@DosCall
	pop ds
	pushfd
	mov ah,3Eh
	@DosCall
	popfd
	jc copydefault
	push eax
	mov ebx,pMem
	mov ax,6
	int 31h
	push cx
	push dx
	pop edi
	mov dwMem,edi
	pop eax
ife ?FLAT
	movzx eax,ax
endif
	mov byte ptr @flat:[edi+eax],0

	mov esi,lpAppName		;search section
	.if (esi)
		call searchsection
		jc copydefault
	.else
		mov esi, edi
		mov ecx,bufsize
		mov edi,retbuff
		call getallsections
		mov rc, eax
		jmp exit
	.endif

	mov esi,lpKeyName
	.if (esi)
		call searchentry
		jc copydefault
		jmp copyvalue
	.else
		mov esi, edi
		mov ecx,bufsize
		mov edi,retbuff
		call getallkeys
		mov rc, eax
	.endif

	jmp exit

copyvalue:
	mov ah,13
	mov esi, edi
	inc esi
	cmp byte ptr @flat:[esi],'"'
	jnz @F
	inc esi
	mov ah,'"'
@@:
	mov edi, retbuff
	mov ecx, bufsize
	jecxz cd2
	dec ecx
@@:
	@flatlodsb
	cmp al,ah
	jz @F
	cmp al,13
	jz @F
	stosb
	loopnz @B
@@:
	mov al,0
	stosb
	sub edi, retbuff
	dec edi
	mov rc, edi
	jmp exit

copydefault:
	mov esi, lpDefault
	mov edi, retbuff
	mov ecx, bufsize
	jecxz cd2
cd1:
	lodsb
;	@flatlodsb
	stosb
	and al,al
	loopnz cd1
	.if (!ecx)
		dec edi
		mov al,0
		stosb
	.endif
	sub edi, retbuff
	dec edi
	mov rc, edi
cd2:

exit:
	.if (pMem)
		push es
		mov es,pMem
		mov ah,49h
		@DosCall
		pop es
	.endif
	mov eax,rc
	ret

GetPrivateProfileStringA endp

	end

