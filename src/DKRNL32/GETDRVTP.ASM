
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

;--- returns:
;--- DRIVE_UNKNOWN
;--- DRIVE_NO_ROOT_DIR
;--- DRIVE_FIXED
;--- DRIVE_REMOVABLE
;--- DRIVE_REMOTE (network)
;--- DRIVE_CDROM
;--- DRIVE_RAMDISK

GetDriveTypeA proc public uses ebx pRoot:ptr BYTE

	mov eax,pRoot
	and eax,eax
	jz @F
	mov ax,[eax]
	cmp ah,':'
	jnz @F
	or al,20h
	sub al,'a'
	jmp sm1
@@:
	mov ah,19h
	int 21h
sm1:
	inc al
	mov bl,al
	mov ax,4409h	;check if drive remote
	int 21h
	jc isinvalid

	cmp bl,2		;A:,B: special handling
	ja @F
	mov ax,440Eh	;get logical drive map
	int 21h
	cmp al,00
	jz isremovable
	cmp al,bl
	jz isremovable
	jmp isinvalid

@@:
	and dh,not 40h
	cmp dx,0800h	;pretty good test for a ramdisk
	jz isramdisk
	test dh,10h		;bit 12 of dx - remote?
	jz isfixed
	mov cl,bl
	dec cl
	mov ch,0
	mov ax,150bh
	int 2Fh
	cmp bx,0ADADh
	jnz isremote
	and ax,ax
	jz isremote
iscdrom:
	mov eax,DRIVE_CDROM
	jmp exit
isremovable:
	mov eax,DRIVE_REMOVABLE
	jmp exit
isramdisk:
	mov eax,DRIVE_RAMDISK
	jmp exit
isremote:
	mov eax,DRIVE_REMOTE
	jmp exit
isinvalid:
	mov eax,DRIVE_NO_ROOT_DIR
	jmp exit
isfixed:
	mov eax,DRIVE_FIXED
exit:
	@strace <"GetDriveTypeA('", &pRoot, "')=", eax>
	ret
	align 4

GetDriveTypeA endp

GetDriveTypeW proc public pRoot:ptr WORD
	mov eax, pRoot
	call ConvertWStr
	invoke GetDriveTypeA, eax
	@strace <"GetDriveTypeW(", pRoot, ")=", eax>
	ret
	align 4
GetDriveTypeW endp

GetLogicalDrives proc public uses ebx esi

	xor esi,esi
	mov bl,01
next:
if 0
	mov ax,4408h		 ;check if drive removeable
	int 21h
	jc @F
else
	mov eax,"\: "
	mov al,bl
	add al,'A'-1
	push eax
	invoke GetDriveTypeA, esp
	pop ecx
	cmp eax, DRIVE_NO_ROOT_DIR
	jz @F
endif
	mov al,bl
	dec al
	movzx eax,al
	bts esi,eax
@@:
	inc bl
	cmp bl,20h
	jb next
	mov eax,esi
	@strace <"GetLogicalDrives()=", eax>
	ret
	align 4

GetLogicalDrives endp

GetLogicalDriveStringsA proc public uses edi nBufferLength:dword, lpBuffer:ptr BYTE

	invoke GetLogicalDrives
	mov ecx, nBufferLength
	mov edi, lpBuffer
	mov edx, "\:A"
	.while (eax)
		.if (al & 1)
			.if (ecx >= 4)
				mov [edi],edx
				sub ecx, 4
			.else
				xor ecx, ecx
			.endif
			add edi, 4
		.endif
		inc dl
		shr eax, 1
	.endw
	mov eax, edi
	.if (ecx)
		mov byte ptr [edi],0
	.endif
	sub eax, lpBuffer
	@strace <"GetLogicalDriveStringsA(", nBufferLength, ", ", lpBuffer, ")=", eax>
	ret
	align 4
GetLogicalDriveStringsA endp

	end
