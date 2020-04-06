
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

;--- ignore pdwOffsHigh

;--- with DOS it is possible to set file pointer before the start of file
;--- (with int 21, ax=4202h, cx:dx=FFFFFFFF after file has been opened)
;--- this is an error for win32

?CHECKNEGATIVEOFFS	equ 1

SetFilePointer proc public uses ebx esi edi handle:dword,dwOffs:dword,pdwOffsHigh:dword,origin:dword

	cmp origin,2		;just 0,1 or 2 allowed
	ja error57
	mov ebx,handle
	mov ecx,pdwOffsHigh
	mov eax,dwOffs
	cdq
	jecxz @F
	mov edx,[ecx]
@@:
	cmp ebx,10000h
	ja isspecial
if ?CHECKNEGATIVEOFFS
	cmp byte ptr origin, 0
	jz normalprocessing
	and edx,edx
	jns normalprocessing	;negative offset with origin 1/2
	cmp edx,-1
	jnz error
	xor edx,edx
	xor ecx,ecx
	mov ax,4201h			;get current file pos
	int 21h
	jc error
	push dx
	push ax
	pop esi					;save current file pos
	cmp byte ptr origin, 1
	jnz fromendprocessing
	mov ecx,dwOffs			;negative offset from current pos
	neg ecx
	cmp esi,ecx
	jc errorX
	jmp normalprocessing2
fromendprocessing:
	xor edx,edx
	xor ecx,ecx
	mov ax,4202h			;go to EOF
	int 21h
	push dx
	push ax					;save file size	
	push esi
	pop dx
	pop cx
	mov ax,4200h			;restore file position
	int 21h
	pop eax
	mov ecx,dwOffs
	neg ecx
	cmp eax,ecx
	jc errorX
normalprocessing2:
	mov eax,dwOffs
	xor edx,edx
normalprocessing:
endif
	and edx,edx
	jnz error
	mov ecx,eax
	mov edx,eax
	shr ecx,16
	mov al,byte ptr origin
	mov ah,42h
	int 21h
	jc error
	push dx
	push ax
	pop eax
	mov ecx, pdwOffsHigh
	jecxz @F
	mov dword ptr [ecx],0
@@:
exit:
	@strace <"SetFilePointer(", handle, ", ", dwOffs, ", ", pdwOffsHigh, ", ", origin, ")=", eax>
	ret
error5:
	mov ax,5	;ERROR_ACCESS_DENIED
	jmp error
error57:
	mov ax,ERROR_INVALID_PARAMETER
	jmp error
errorX:
	mov ax,83h	;ERROR_NEGATIVE_SEEK
error:
	movzx eax,ax
	invoke SetLastError,eax
	@mov eax,-1
	jmp exit

;--- edx:eax == 64bit offset
;--- ecx == pdwOffsHigh

isspecial:
	cmp ebx,-1
	jz error5
	cmp [ebx].FILE.dwType, SYNCTYPE_FILE
	jnz error5
	test [ebx].FILE.flags, FF_DISK or FF_DRIVE
	jz error5
	cmp origin,1	;relative?
	jz @F
	cmp origin,0	;absolute?
	jnz error5
	xchg dword ptr [ebx].FILE.dqPos+0, eax
	xchg dword ptr [ebx].FILE.dqPos+4, edx
ifdef _DEBUG
	and ecx,ecx
	jz exit
else
	jecxz exit
endif
	mov [ecx],edx
	jmp exit
@@:
	push dword ptr [ebx].FILE.dqPos+4
	push dword ptr [ebx].FILE.dqPos+0
	add dword ptr [ebx].FILE.dqPos+0, eax
	adc dword ptr [ebx].FILE.dqPos+4, edx
	pop eax
	pop edx
ifdef _DEBUG
	and ecx,ecx
	jz exit
else
	jecxz exit
endif
	mov [ecx],edx
	jmp exit
	align 4

SetFilePointer endp

SetFilePointerEx proc public handle:dword, dqDistance:QWORD,
			lpNewDistance:ptr QWORD, dwMoveMethod:dword

	mov edx, lpNewDistance
	and edx, edx
	jz @F
	add edx, 4
	mov eax, dword ptr dqDistance+4
	mov [edx], eax
@@:
	invoke SetFilePointer, handle, dword ptr dqDistance+0, edx, dwMoveMethod
	.if (eax != -1)
		mov edx, lpNewDistance
		and edx, edx
		jz @F
		mov [edx], eax
@@:
		@mov eax, 1
	.else
		inc eax
	.endif
	@strace <"SetFilePointerEx(", handle, ", ", <dword ptr dqDistance+0>, '.', <dword ptr dqDistance+4>, ", ", lpNewDistance, ", ", dwMoveMethod, ")=", eax>
	ret
	align 4

SetFilePointerEx endp

	end

